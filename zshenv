WAKATIME_USE_DIRNAME=true

[ -d /usr/local/sbin ] && export PATH=/usr/local/sbin:$PATH
[ -d $HOME/.bin ] && export PATH=$HOME/.bin:$PATH
[ -d $HOME/.go ] && export GOPATH=$HOME/.go && export PATH=$GOPATH/bin:$PATH

export ANDROID_HOME=/usr/local/opt/android-sdk
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export AIRFLOW_HOME=$HOME/.airflow

[ -f $HOME/.zshsecrets ] && source $HOME/.zshsecrets

export PIPENV_VENV_IN_PROJECT=1
