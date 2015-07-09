class Rugged::Repository
  def create_remote_if_needed(remote_url_wanted, remote_name_suggestion)
    remotes.each do |remote|
      return remote.name if remote.url == remote_url_wanted
    end
    remote_name_used = remote_name_suggestion
    number = 1
    while remotes.any? {|remote| remote.name == remote_name_suggestion }
      number += 1
      remote_name_used = "#{remote_name_suggestion}#{number}"
    end
    remotes.create remote_name_used, remote_url_wanted
    remote_name_used
  end
end

class Rugged::Tree
  def include_file?(relative_path)
    begin
      path(relative_path.to_s)
      return true
    rescue Rugged::TreeError
      return false
    end
  end
end
