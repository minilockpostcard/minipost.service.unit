# [Flightplan](https://github.com/pstadler/flightplan) executes command sequences on local and remote hosts.
Flightplan = require "flightplan"

flightplan = new Flightplan
flightplan.briefing
  destinations:
    "sin": [{
      host: "sin.minipost.link" # "128.199.251.131"
      username: "core"
      agent: process.env.SSH_AUTH_SOCK
      readyTimeout: 30000
    }]
    "nyc": [{
      host: "nyc.minipost.link" # "104.131.76.101"
      username: "core"
      agent: process.env.SSH_AUTH_SOCK
      readyTimeout: 30000
    }]

flightplan.remote ["reboot"], (remote) ->
  remote.sudo("reboot --force --reboot")

flightplan.remote ["status", "inspect", "default"], (remote) ->
  remote.exec "id"
  remote.exec "df /"
  remote.exec "docker images"
  remote.exec "docker ps --all"
  remote.exec "docker info"
  remote.exec "systemctl status minipost"

flightplan.remote "start", (remote) ->
  remote.sudo "systemctl start minipost"
  remote.exec "systemctl status minipost"

flightplan.remote "stop", (remote) ->
  remote.sudo "systemctl stop minipost"
  remote.exec "systemctl status minipost", failsafe: true

flightplan.remote ["restart"], (remote) ->
  remote.sudo("systemctl stop minipost")
  remote.sudo("systemctl start minipost")
  remote.exec("systemctl status minipost")

flightplan.remote ["setup", "setup_public_folder"], (remote) ->
  if remote.exec("ls minipost", failsafe:yes, silent:yes).code isnt 0
    remote.log "Establishing minipost folder for publically accesible files"
    remote.exec "mkdir minipost"
  else
    remote.log "minipost folder for publically accesible files is established"

flightplan.remote ["setup", "setup_repo"], (remote) ->
  if remote.exec("ls minipost.git", failsafe:yes, silent:yes).code isnt 0
    remote.log "Making minipost.git to receive deploy commits"
    remote.exec("git init --bare minipost.git")
  else
    remote.log "minipost.git is established"

flightplan.local ["setup", "setup_repo"], (local) ->
  local.log "Adding post receive hook to minipost.git"
  local.transfer "git-post-receive-hook", "minipost.git/hooks/post-receive"

flightplan.local ["setup", "build"], (local) ->
  imageFiles = [
    "#{flightplan.target.destination}.Dockerfile"
    "#{flightplan.target.destination}.minipost.link.crt"
    "#{flightplan.target.destination}.minipost.link.secret.key"
    "#{flightplan.target.destination}.nginx.conf"
  ]
  local.log "Transfering minipost_image files:", JSON.stringify(imageFiles)
  local.transfer imageFiles, "/home/core/minipost_image"

flightplan.remote ["setup", "build"], (remote) ->
  remote.log "Building /home/core/minipost_image"
  remote.exec "mv /home/core/minipost_image/#{flightplan.target.destination}.Dockerfile /home/core/minipost_image/Dockerfile"
  remote.exec "docker build --tag minipost_image /home/core/minipost_image"
  remote.exec "docker images"
  remote.log "Removing build files"
  remote.exec "rm -rf minipost_image"

flightplan.local ["setup", "setup_service"], (local) ->
  local.log "Transfering minipost.service unit file"
  local.transfer "minipost.service", "/home/core"

flightplan.remote ["setup", "setup_service"], (remote) ->
  remote.log "Linking minipost service with systemd"
  remote.sudo "systemctl link /home/core/minipost.service"

flightplan.remote ["erase"], (remote) ->
  remote.exec("rm -rf minipost")
  remote.exec("rm -rf minipost_image")
  remote.exec("rm -rf minipost.git")
  remote.exec("rm -rf minipost.service")

flightplan.remote ["erase", "clean", "remove_expired_docker_containers"], (remote) ->
  expiredContainerList = remote.exec("docker ps --all | grep Exited", {failsafe:yes}).stdout
  if expiredContainerList
    containerIDs = (entry.split(" ")[0] for entry in expiredContainerList.trim().split("\n")).join(" ")
    remote.log "Removing containers:", containerIDs
    remote.exec "docker rm #{containerIDs}"
  else
    remote.log "No expired docker containers."

flightplan.remote ["erase", "clean", "remove_expired_docker_images"], (remote) ->
  expiredImageList = remote.exec("docker images | grep '^<none>' | awk '{print $3}'", failsafe:yes).stdout
  if expiredImageList
    expiredImageIDs = (id for id in expiredImageList.trim().split("\n")).join(" ")
    console.info expiredImageIDs
    remote.log "Removing containers:", expiredImageIDs
    remote.exec("docker rmi #{expiredImageIDs}")
  else
    remote.log "No expired docker images."

flightplan.local ["certify"], (local) ->
  {existsSync, readFileSync, writeFileSync} = require "fs"
  unless existsSync "nyc.minipost.link.secret.key"
    local.exec "openssl genrsa -out nyc.minipost.link.secret.key 2048"
    local.log "Generated secret key: nyc.minipost.link.secret.key"
  unless existsSync "nyc.minipost.link.crt"
    local.waitFor (complete) =>
      Authority = require "authority"
      Authority.createCertificate
        "subject":
          "title":               "Autonomous miniLock Postcard"
          "organization":        "miniLock Postcard"
          "organizational_unit": "Department of supercryptographicellipticurvexpialidocious."
          "business_category":   "Encrypted communication for people without personal computers."
          "location":            "https://auto.minipost.link"
          "email_address":       "undefined@minipost.link"
          "region":              "New York"
          "country_code":        "US"
          "user_id":             "minipostlink"
          "common_name":         "auto.minipost.link"
        "subject_key": readFileSync "nyc.minipost.link.secret.key"
        "started_at": (new Date).toJSON()
        "expires_at": "2015-01-01T00:00:01.000Z"
        "callback": (error, certificate) ->
          throw error if error
          writeFileSync "nyc.minipost.link.crt", certificate.pem
          local.log "Created certificate:  nyc.minipost.link.crt"
          complete()
