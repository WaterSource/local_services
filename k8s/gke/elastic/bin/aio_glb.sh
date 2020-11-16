#!/bin/bash

# Author: Bin Wu <binwu@google.com>
set -e
__usage() {
    echo "Usage: ./bin/glb.sh {reserve|release|status|deploy|dns|clean}"
}

__reserve_ip() {
    gcloud compute addresses create $GCIP_NAME --global --project "${GKE_PROJECT_ID}"

    gcloud compute addresses describe $GCIP_NAME --global --project "${GKE_PROJECT_ID}" | grep "address:" | cut -d ' ' -f 2
}

__release_ip() {
    echo "Y" | gcloud compute addresses delete $GCIP_NAME --global --project "${GKE_PROJECT_ID}"
}

__cert() {
    # delete the certificate
    # kubectl delete -f $PWD/deploy/cert.yml
    eval "cat <<EOF
$(<"$PWD"/templates/cert.yml)
EOF
" 2>/dev/null >"$PWD"/deploy/cert.yml
    kubectl delete -f "$PWD"/deploy/cert.yml

    # create the certificate
    # kubectl apply -f $PWD/deploy/cert.yml
    eval "cat <<EOF
$(<"$PWD"/templates/cert.yml)
EOF
" 2>/dev/null >"$PWD"/deploy/cert.yml
    kubectl apply -f "$PWD"/deploy/cert.yml

}

__status() {
    # gcloud compute addresses list --filter="name=$GCIP_NAME"
    gcloud compute addresses describe $GCIP_NAME --global --project "${GKE_PROJECT_ID}"
}

__deploy() {
    # kubectl apply -f $PWD/deploy/lb.yml
    eval "cat <<EOF
$(<"$PWD"/templates/lb.yml)
EOF
" 2>/dev/null >"$PWD"/deploy/lb.yml
    kubectl apply -f "$PWD"/deploy/lb.yml
}

__dns() {

    __clean_dns

    gclb_ip=$(gcloud compute addresses describe $GCIP_NAME --global --project "${GKE_PROJECT_ID}" | grep "address:" | cut -d ' ' -f 2)

    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction start --zone="$ES_DOMAINS_ZONE"

    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction add $gclb_ip --name="$K8S_ES_INGRESS_DOMAINS"\. --ttl=300 --type=A --zone="$ES_DOMAINS_ZONE"
    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction add 0\ issue\ \"letsencrypt.org\" 0\ issue\ \"pki.goog\" --name="$K8S_ES_INGRESS_DOMAINS"\. --ttl=300 --type=CAA --zone="$ES_DOMAINS_ZONE"

    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction add $gclb_ip --name="$K8S_ES_COODR_DOMAINS"\. --ttl=300 --type=A --zone="$ES_DOMAINS_ZONE"
    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction add 0\ issue\ \"letsencrypt.org\" 0\ issue\ \"pki.goog\" --name="$K8S_ES_COODR_DOMAINS"\. --ttl=300 --type=CAA --zone="$ES_DOMAINS_ZONE"

    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction add $gclb_ip --name="$K8S_ES_KIBANA_DOMAINS"\. --ttl=300 --type=A --zone="$ES_DOMAINS_ZONE"
    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction add 0\ issue\ \"letsencrypt.org\" 0\ issue\ \"pki.goog\" --name="$K8S_ES_KIBANA_DOMAINS"\. --ttl=300 --type=CAA --zone="$ES_DOMAINS_ZONE"

    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction execute --zone="$ES_DOMAINS_ZONE"

}

__clean_dns() {
    gclb_ip=$(gcloud compute addresses describe $GCIP_NAME --global --project "${GKE_PROJECT_ID}" | grep "address:" | cut -d ' ' -f 2)

    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction start --zone="$ES_DOMAINS_ZONE"

    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction remove $gclb_ip --name="$K8S_ES_INGRESS_DOMAINS"\. --ttl=300 --type=A --zone="$ES_DOMAINS_ZONE"
    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction remove 0\ issue\ \"letsencrypt.org\" 0\ issue\ \"pki.goog\" --name="$K8S_ES_INGRESS_DOMAINS"\. --ttl=300 --type=CAA --zone="$ES_DOMAINS_ZONE"

    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction remove $gclb_ip --name="$K8S_ES_COODR_DOMAINS"\. --ttl=300 --type=A --zone="$ES_DOMAINS_ZONE"
    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction remove 0\ issue\ \"letsencrypt.org\" 0\ issue\ \"pki.goog\" --name="$K8S_ES_COODR_DOMAINS"\. --ttl=300 --type=CAA --zone="$ES_DOMAINS_ZONE"

    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction remove $gclb_ip --name="$K8S_ES_KIBANA_DOMAINS"\. --ttl=300 --type=A --zone="$ES_DOMAINS_ZONE"
    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction remove 0\ issue\ \"letsencrypt.org\" 0\ issue\ \"pki.goog\" --name="$K8S_ES_KIBANA_DOMAINS"\. --ttl=300 --type=CAA --zone="$ES_DOMAINS_ZONE"

    gcloud dns --project "${GKE_PROJECT_ID}" record-sets transaction execute --zone="$ES_DOMAINS_ZONE"

}

__clean() {
    # kubectl delete -f $PWD/deploy/lb.yml
    eval "cat <<EOF
$(<"$PWD"/templates/lb.yml)
EOF
" 2>/dev/null >"$PWD"/deploy/lb.yml
    kubectl delete -f "$PWD"/deploy/lb.yml

    __clean_dns
}

__main() {
    if [ $# -eq 0 ]; then
        __usage
    else
        case $1 in
        reserve | r)
            __reserve_ip
            ;;
        release)
            __release_ip
            ;;
        status | s)
            __status
            ;;
        cert)
            __cert
            ;;
        deploy | d)
            __deploy
            ;;
        dns)
            __dns
            ;;
        clean)
            __clean
            ;;
        *)
            __usage
            ;;
        esac
    fi
}

__main $@
