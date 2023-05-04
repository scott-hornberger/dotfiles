export WEBPOD=sth.devpod-nld
alias podfwd='ssh -N -L 8888:localhost:8888 $WEBPOD'
alias niels='echo "pedersen" | sudo tee -a /etc/ssh/authorized_principals'
