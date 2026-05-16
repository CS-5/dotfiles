function __ssh_agent_is_started -d "check if ssh agent is already started"
   if begin; test -f $SSH_ENV; and test -z "$SSH_AGENT_PID"; end
      source $SSH_ENV > /dev/null
   end

   if test -z "$SSH_AGENT_PID"
      return 1
   end

   ps -ef | grep $SSH_AGENT_PID | grep -v grep | grep -q ssh-agent
   return $status
end


function __ssh_agent_start -d "start a new ssh agent"
   ssh-agent -c | sed 's/^echo/#echo/' > $SSH_ENV
   chmod 600 $SSH_ENV
   source $SSH_ENV > /dev/null
   true
end


function fish_ssh_agent --description "Start ssh-agent or load keys from the macOS Keychain."
   # macOS: launchd already runs a Keychain-aware ssh-agent at SSH_AUTH_SOCK.
   # Pull any passphrases previously saved via `ssh-add --apple-use-keychain`
   # into that agent so git/ssh stop prompting.
   if test (uname -s) = Darwin
      ssh-add --apple-load-keychain --quiet 2>/dev/null
      return
   end

   if test -z "$SSH_ENV"
      set -xg SSH_ENV $HOME/.ssh/environment
   end

   if not __ssh_agent_is_started
      __ssh_agent_start
   end
end
