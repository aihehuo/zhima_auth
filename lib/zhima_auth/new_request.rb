module ZhimaAuth
  module Alipay
    class BaseRequest
      REQUEST_GATEWAY = 'https://openapi.alipay.com/gateway.do'

      def url
        REQUEST_GATEWAY
      end

      def base_params
        @base_params ||= {
          app_id: ZhimaAuth.configuration.app_id,
          charset: ZhimaAuth.configuration.charset,
          format: ZhimaAuth.configuration.format,
          sign_type: ZhimaAuth.configuration.sign_type,
          version: ZhimaAuth.configuration.version,
        }
      end

      def params_with_sign
        params.merge({sign: Sign.encode(params)})
      end
    end

    class InitializeRequest < BaseRequest
      attr_accessor :cert_name, :cert_no, :transaction_id
      # { cert_name: "Bran", cert_no: "3543563267268", transaction_id: "AIHEHUO20170101000000001" }
      def initialize(biz_params)
        Validation.check_initialize_params(biz_params)

        @cert_name = biz_params[:cert_name]
        @cert_no = biz_params[:cert_no]
        @transaction_id = biz_params[:transaction_id]
        @return_url = biz_params[:return_url]
      end

      def execute
        @response ||= RestClient.post url_with_params, {}
      end

      def get_certify_id
        res = JSON.parse(execute)
        Validation.check_initialize_response res
        res["alipay_user_certify_open_initialize_response"]["certify_id"]
      end

      private

      def params
        @params ||= base_params.merge({
          method: "alipay.user.certify.open.initialize",
          timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
          biz_content: {
            outer_order_no: @transaction_id,
            biz_code: ZhimaAuth.configuration.biz_code,
            identity_param: {
              identity_type: "CERT_INFO",
              cert_type: "IDENTITY_CARD",
              cert_name: @cert_name,
              cert_no: @cert_no
            },
            merchant_config: {"return_url": @return_url}
          }.to_json
        })
      end

      def url_with_params
        [url, WebUtil.to_query(params_with_sign)].join("?")
      end

    end

    class CertifyRequest < BaseRequest

      # { biz_no: "MK62873648327468", return_url: "https://www.google.com" }
      def initialize(biz_params)
        Validation.check_certify_params biz_params

        @certify_id = biz_params[:biz_no]
        @return_url = biz_params[:return_url]
      end

      def generate_url
        [url, URI.encode_www_form(params_with_sign)].join("?")
      end

      private

      def params
        @params ||= base_params.merge({
          method: "alipay.user.certify.open.certify",
          return_url: @return_url,
          timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
          biz_content: {
            certify_id: @certify_id
          }.to_json
        })
      end

    end

    class QueryRequest < BaseRequest

      def initialize(biz_no)
        Validation.check_biz_no biz_no

        @biz_no = biz_no
      end

      def execute
        @response ||= (RestClient.post url, params_with_sign).encode(Encoding.find("utf-8"),Encoding.find("gbk"))
        Rails.logger.info "zhima_auth request: #{@response}"
        @response
      end

      def get_certify_result
        result = execute
        res = JSON.parse(result)
        Validation.check_query_response res
        res["alipay_user_certify_open_query_response"]["passed"]
      end

      private

      def params
        @params ||= base_params.merge({
          method: "alipay.user.certify.open.query",
          timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
          biz_content: {
            certify_id: @biz_no
          }.to_json
        })
      end
    end
  end
end
