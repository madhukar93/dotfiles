function drc --wraps='docker compose' --description 'alias drc=docker compose'
  docker compose $argv; 
end
