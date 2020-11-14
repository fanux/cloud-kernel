FROM golang:1.11.3
COPY config.sh .
RUN wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && mv jq-linux64 jq && chmod +x jq && mv jq /usr/bin
RUN wget https://github.com/aliyun/aliyun-cli/releases/download/v3.0.26/aliyun-cli-linux-3.0.26-amd64.tgz && tar zxvf aliyun-cli-linux-3.0.26-amd64.tgz && cp aliyun /usr/bin && rm aliyun-cli-linux-3.0.26-amd64.tgz
# COPY sshpass-1.06 sshpass-1.06
# RUN cd sshpass-1.06 && ./configure --prefix=/usr && make && make install
RUN wget https://github.com/cuisongliu/shell/releases/download/v1.0/shell && chmod +x shell && mv shell /usr/bin/sshcmd
RUN wget https://github.com/oldthreefeng/mycli/releases/download/1.0.0/mycli && chmod +x mycli && mv shell /usr/bin/mycli
