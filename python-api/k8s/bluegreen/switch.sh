#!/bin/bash
kubectl annotate ingress python-api-ingress \
  alb.ingress.kubernetes.io/actions.forward-active='{
    "type":"forward",
    "forwardConfig":{
      "targetGroups":[
        {"serviceName":"python-api-green","servicePort":"80"}
      ]
    }
  }' --overwrite