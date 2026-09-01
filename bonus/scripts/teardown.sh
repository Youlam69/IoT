#!/bin/bash
# Removes GitLab and the cluster.
helm uninstall gitlab -n gitlab
k3d cluster delete iot
sudo sed -i '/# iot-bonus/d' /etc/hosts
