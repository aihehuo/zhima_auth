module ZhimaAuth
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
    end

    def execute
      @response ||= RestClient.post url_with_params, {}
    end

    def get_biz_no
      res = JSON.parse(execute)
      Validation.check_initialize_response res
      res["zhima_customer_certification_initialize_response"]["biz_no"]
    end

    private

    def params
      @params ||= base_params.merge({
        method: "zhima.customer.certification.initialize",
        timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        biz_content: {
          transaction_id: @transaction_id,
          product_code: "w1010100000000002978",
          biz_code: ZhimaAuth.configuration.biz_code,
          identity_param: {
            identity_type: "CERT_INFO",
            cert_type: "IDENTITY_CARD",
            cert_name: @cert_name,
            cert_no: @cert_no
          }
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

      @biz_no = biz_params[:biz_no]
      @return_url = biz_params[:return_url]
    end

    def generate_url
      [url, URI.encode_www_form(params_with_sign)].join("?")
    end

    private

    def params
      @params ||= base_params.merge({
        method: "zhima.customer.certification.certify",
        return_url: @return_url,
        timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        biz_content: {
          biz_no: @biz_no
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
      res["zhima_customer_certification_query_response"]
    end

    private

    def params
      @params ||= base_params.merge({
        method: "zhima.customer.certification.query",
        timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        biz_content: {
          biz_no: @biz_no
        }.to_json
      })
    end

  end

  class AuthQueryRequest < BaseRequest
    def initialize biz_params
      @userId = biz_params[:userId]
      @cert_name = biz_params[:cert_name]  
    end

    def execute
      "alipays://platformapi/startapp?appId=20000067&url=" + CGI.escape(url_with_params)
    end

    private
    def url_with_params
      [url, WebUtil.to_query(params_with_sign)].join("?")
    end

    def params
      @params ||= base_params.merge({
        method: "zhima.auth.info.authquery",
        timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        biz_content: {
          identity_type: "5",
          identity_param: {
            userId: @userId
          },
          auth_category: "C2ConB"
        }.to_json
      })
    end
  end

  class MutualViewApplyRequest < BaseRequest
    def initialize biz_params
      @cert_type = biz_params[:cert_type]
      @cert_name = biz_params[:cert_name]
      @cert_no = biz_params[:cert_no]  
      @callback_url = biz_params[:callback_url]  
      @ext_biz_param = biz_params[:ext_biz_param]   
    end

    def execute
      "alipays://platformapi/startapp?appId=20000067&url=" + CGI.escape(url_with_params)
    end

    private
    def url_with_params
      [url, WebUtil.to_query(params_with_sign)].join("?")
    end

    def params
      @params ||= base_params.merge({
        method: "zhima.customer.auth.mutualview.apply",
        timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
        biz_content: {
          product_param: {
            productCode: "w1010100001000002181"
          },
          biz_type: "self",
          identity_param: {
            certType: "IDENTITY_CARD",
            name: @cert_name,
            certNo: @cert_no
          }, 
          callback_url: @callback_url,
          ext_biz_param: @ext_biz_param
        }.to_json
      })
    end
  end

end
