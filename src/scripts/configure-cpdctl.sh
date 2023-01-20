#! /bin/bash

export PATH=$PATH:$HOME/bin
cpdctl config user set cpd_user --username ${CPD_USER_NAME} --apikey ${CPD_USER_APIKEY}
cpdctl config profile set cpd --url ${CPD_URL}
cpdctl config context set cpd --profile cpd --user cpd_user