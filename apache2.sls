# Set environment name int/stage/prod
{% set envString = 'int' %}

# Vhost configuration
{% set vhostFileName = '<vhost file name>' %}
{% set vhostServerName = '<domain name>' %}
{% set listenPort = '<listen port>' %}

# Paths
{% set dataPath = '<document root>' %}
{% set logPath = '<directory to store logs>' %}
{% set apacheInstallDir = '/etc/apache2' %}

# User/Group
{% set apacheUser = '<apache_user>' %}
{% set apacheGroup = '<apache_group>' %}

# Get server IP of eth0 interface - used in Smoke Tests only
{% set serverIPAddress = salt['network.interfaces']()['eth0']['inet'][0]['address'] %}
# Get hostname
{% set serverHostname = salt['grains.get']('host') %}

# Set ENVIRONMENT variable
setEnvVariable:
   environ.setenv:
     - name: ENVIRONMENT
     - value: {{ envString }}
     - update_minion: True

# Install apache
apache2:
  pkg:
    - name: apache2
    - installed

# Add Group
webserverGroup:
  group.present:
    - name: {{ apacheGroup }}
    - addusers:
      - {{ apacheUser }}

# Add User
webserverUser:
  user.present:
    - name: {{ apacheUser }}
    - shell: /bin/false
    - home: /home/{{ apacheUser }}
    - groups:
      - {{ apacheGroup }}

# Create env dir - DocumentRoot
envDir:
  file.directory:
    - name: {{ dataPath }}/{{ envString }}/htdocs/infra
    - user: root
    - group: root
    - dir_mode: 755
    - file_mode: 644
    - makedirs: True
    - recurse:
      - user
      - group
      - mode

# Create logs dir
logPath:
  file.directory:
    - name: {{ logPath }}/{{ envString }}
    - user: {{ apacheUser }}
    - group: {{ apacheGroup }}
    - dir_mode: 755
    - file_mode: 644
    - makedirs: True
    - recurse:
      - user
      - group
      - mode

# Create or replace uid.conf with Apache user and group name
uid.conf:
  file.managed:
    - name: {{ apacheInstallDir }}/uid.conf
    - user: root
    - group: root
    - replace: True
    - contents:
      - User {{ apacheUser }}
      - Group {{ apacheGroup }}

# Create or replace lbtest1.html with: environment - hostname
lbtest1.html:
  file.managed:
    - name: {{ dataPath }}/{{ envString }}/htdocs/infra/lbtest1.html
    - user: root
    - group: root
    - replace: True
    - contents: |
        <html>
          <head>
              <title> {{ envString }} - {{ serverHostname }} </title>
          </head>
          <body>
              <pre>
                  {{ envString }} - {{ serverHostname }}

                  Status: OK
              </pre>
          </body>
        </html>

# Create or replace WhereAmI.Info with env - hostname
WhereAmI.info:
  file.managed:
    - name: {{ dataPath }}/{{ envString }}/htdocs/infra/WhereAmI.info
    - user: root
    - group: root
    - replace: True
    - contents:
      - {{ envString }} - {{ serverHostname }}

# Create or replace listen.conf - Listen port
listen.conf:
  file.managed:
    - name: {{ apacheInstallDir }}/listen.conf
    - user: root
    - group: root
    - replace: True
    - contents:
      - Listen {{ listenPort }}

# Copy Virtual host from Salt Master - (force: True is used to overwrite file if exists)
copyVhostFile:
  file.managed:
    - name: {{ apacheInstallDir }}/vhosts.d/{{ vhostFileName }}
    - source: salt://apache2_4/files/{{ vhostFileName }}
    - force: True
    - makedirs: True
    - user: root
    - group: root
    - mode: 644
    
# Copy Virtual host - 00_default (force: True is used to overwrite file if exists)
00_default.conf:
  file.managed:
    - name: {{ apacheInstallDir }}/vhosts.d/00_default.conf
    - source: salt://apache2_4/files/00_default.conf
    - force: True
    - user: root
    - group: root
    - mode: 644

# Find and replace all occurances of <env> with the current environment
replaceEnvInVhost:
  file.replace:
    - name: {{ apacheInstallDir }}/vhosts.d/{{ vhostFileName }}
    - backup: original
    - pattern: <env>
    - repl: {{ envString }}

# Find and replace all occurances of <env> with the current environment
replaceEnvInDefaultVhost:
  file.replace:  
    - name: {{ apacheInstallDir }}/vhosts.d/00_default.conf 
    - backup: _original
    - pattern: <env>
    - repl: {{ envString }}

# Add ServerName to vhost   
replaceSrvNameInVhost:
  file.replace:
    - name: {{ apacheInstallDir }}/vhosts.d/{{ vhostFileName }}
    - backup: _original
    - pattern: <server_name>
    - repl: {{ vhostServerName }}

# Enable apache2 service to be started at runtime and start apache2 now.
enableAndStartApache:
  service.running:
    - name: apache2
    - enable: True
    
# Get IP of eth0 and execute smoke tests towards it
smokeTestWithIP:
  cmd.run:
    - name: curl -v http://{{ serverIPAddress }}:{{ listenPort }}/infra/lbtest1.html

smokeTestWithHostAndIP:
  cmd.run:
    - name: curl -v -H "host:{{ vhostServerName }}" http://{{ serverIPAddress }}:{{ listenPort }}/infra/lbtest1.html
