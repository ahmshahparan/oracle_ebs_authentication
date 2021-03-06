require "ruby_plsql"

module OracleEbsAuthentication
  class Authenticator
    def initialize
      @security = OracleEbsAuthentication::Security.new
    end

    def get_fnd_password(username, password)
      username &&= username.upcase
      result = plsql.apps.fnd_security_pkg.fnd_encrypted_pwd(username, nil, nil, nil)
      if result[:p_password]
        @security.decrypt(username + "/" + password, result[:p_password], false)
      end
    rescue OCIError => e
      if e.message.include?("ORA-20001: Your account does not exist or has expired.")
        nil
      else
        raise e
      end
    end

    def get_fnd_user_id(username)
      username &&= username.upcase
      plsql.apps.fnd_security_pkg.fnd_encrypted_pwd(username, nil, nil, nil)[:p_user_id]
    end

    def get_fnd_responsibilities(username)
      user_id = get_fnd_user_id(username)
      if user_id
        plsql.select(:all, <<-SQL, user_id).map{|row| row[:responsibility_name]}
          SELECT r.responsibility_name
            FROM apps.fnd_user_resp_groups_all ur, apps.fnd_responsibility_vl r
           WHERE ur.user_id = :p_user_id
             AND TRUNC(SYSDATE) BETWEEN NVL(ur.start_date,TRUNC(SYSDATE)) AND NVL(ur.end_date, TRUNC(SYSDATE))
             AND ur.responsibility_id = r.responsibility_id
        SQL
      else
        []
      end
    end

    def validate_user_password(username, password)
      if username && password
        !! get_fnd_password(username, password)
      end
    end
  end
end
