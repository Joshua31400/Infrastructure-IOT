docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

docker network rm zone-a-iot zone-b-admin zone-c-bureautique zone-d-dmz

docker volume prune -f