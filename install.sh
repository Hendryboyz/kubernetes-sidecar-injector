helm --kubeconfig ~/k3s-twm.yaml install license-injector . -n ailabs-infra
helm --kubeconfig ~/k3s-twm.yaml uninstall license-injector -n ailabs-infra

helm --kubeconfig ~/k3s-twm.yaml install injected-service . -n asr
helm --kubeconfig ~/k3s-twm.yaml uninstall injected-service -n asr

docker build -t hendryboyz/license-verify-injector:1.0.1 .
docker tag hendryboyz/license-verify-injector:latest hendryboyz/license-verify-injector:1.0.0
docker push hendryboyz/license-verify-injector:1.0.1

