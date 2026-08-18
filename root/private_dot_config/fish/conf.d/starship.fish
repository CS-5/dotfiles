# See mise.fish for why this checks the activation, not just `status is-interactive`.
if status is-interactive; and not functions -q __starship_set_job_count
    starship init fish | source
end
