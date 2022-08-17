#/usr/bin/bash

###################################################
#
# Script to upload a Let's Encrypt certificate
# (or other) into Oracle Cloud Load Balancer
#
###################################################

####################################
#                                  #
#       Variable definition        #
#                                  #
####################################

now=$(date "+%Y%m%d_%H%M")
CertificateName=Certificate-$now
Protocol=HTTP
Port=443
ocicli=/home/opc/bin/oci/bin/oci
#
# Only change the variables below
#
ListenerName=listener-k3s-https
BackendName=bs_lb_2022-0707-1743
LB_OCID=ocid1.loadbalancer.oc1.iad.aaaaaaaauv4yeqqsezznvutn3xi5vp4hogqxzgbndbklyreez5p553g7llza
certificate_path=/etc/letsencrypt/live/martens.live

####################################
# Create Certificate in LB         #
####################################
echo "Creating Certificate $CertificateName in Listener $ListenerName"

$ocicli lb certificate create \
        --certificate-name $CertificateName \
        --load-balancer-id $LB_OCID \
        --private-key-file "$certificate_path/privkey.pem" \
        --public-certificate-file "$certificate_path/fullchain.pem"

#
# Give it 10 seconds for the certificate to be available
#
echo "-- Waiting 60 seconds for certificate to be available on OCI"
sleep 60

####################################
#  Update certificate on Listener  #
####################################
echo "Configuring Listener $ListenerName with certificate $CertificateName"

$ocicli lb listener update \
        --default-backend-set-name $BackendName \
        --listener-name $ListenerName \
        --load-balancer-id $LB_OCID \
        --port $Port \
        --protocol $Protocol \
        --ssl-certificate-name $CertificateName \
        --force

####################################
#  Import cert in k8s              #
####################################
echo "Creating the secret in Kubernetes"


echo "Creating secret in production namespace"
kubectl delete secret ckm-certificate-secret --namespace production
kubectl create secret generic ckm-certificate-secret --from-file=tls.crt=$certificate_path/fullchain.pem --from-file=tls.key=$certificate_path/privkey.pem --namespace production

echo "Creating secret in security namespace"
kubectl delete secret ckm-certificate-secret --namespace security
kubectl create secret generic ckm-certificate-secret --from-file=tls.crt=$certificate_path/fullchain.pem --from-file=tls.key=$certificate_path/privkey.pem --namespace security