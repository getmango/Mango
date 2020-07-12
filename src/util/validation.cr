def validate_username(username)
  if username.size < 3
    raise "Username should contain at least 3 characters"
  end
  if (username =~ /^[A-Za-z0-9_]+$/).nil?
    raise "Username should contain alphanumeric characters " \
          "and underscores only"
  end
end

def validate_password(password)
  if password.size < 6
    raise "Password should contain at least 6 characters"
  end
  if (password =~ /^[[:ascii:]]+$/).nil?
    raise "password should contain ASCII characters only"
  end
end

def validate_archive(path : String) : Exception?
  file = nil
  begin
    file = ArchiveFile.new path
    file.check
    file.close
    return
  rescue e
    file.close unless file.nil?
    e
  end
end
