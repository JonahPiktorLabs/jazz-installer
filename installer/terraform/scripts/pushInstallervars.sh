#!/bin/sh
scm_username=$1
scm_passwd=$2
scm_elb=$3
scm_path=$4
cognito_pool_username=$5

#Encoded username/password for git clone
scmuser_encoded=$(python3 -c "from urllib.parse import quote_plus; print(quote_plus('$scm_username'))")
scmpasswd_encoded=$(python3 -c "from urllib.parse import quote_plus; print(quote_plus('$scm_passwd'))")

rm -rf jazz-build-module
git clone http://"$scmuser_encoded":"$scmpasswd_encoded"@"$scm_elb""$scm_path"/slf/jazz-build-module.git --depth 1
cd jazz-build-module || exit
cp "$JAZZ_INSTALLER_ROOT"/installer/terraform/provisioners/cookbooks/jenkins/files/default/jazz-installer-vars.json .
git add jazz-installer-vars.json
git config --global user.email "$cognito_pool_username"
git commit -m 'Adding Json file to repo'
git push -u origin master
cd .. || exit
rm -rf jazz-build-module
