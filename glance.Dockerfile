FROM  glanceapp/glance:latest

RUN apk add tzdata

RUN cp /usr/share/zoneinfo/America/New_York /etc/localtime
RUN cp /usr/share/zoneinfo/America/New_York /etc/timezone
