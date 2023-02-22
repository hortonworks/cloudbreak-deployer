FROM golang:1.12
RUN go get -u github.com/jteeuwen/go-bindata/...
ADD . /go/src/github.com/hortonworks/cloudbreak-deployer
WORKDIR /go/src/github.com/hortonworks/cloudbreak-deployer