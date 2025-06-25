docker build -t genome_browser .
docker run -d \
  --name genome_browser \
  -e HOST_IP=$(curl -s ifconfig.me) \
  -p 3838:3838 \
  -p 3000:3000 \
  -p 4567:4567 \
  genome_browser
