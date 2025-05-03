work around to authentication issue resulting from runpod execution order.
RunPod tries to pull that image immediately at container creation time, before init script runs — which is too late to authenticate.
