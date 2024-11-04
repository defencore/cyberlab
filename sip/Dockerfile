# Base image
FROM andrius/asterisk

# Copy configuration files
COPY config/asterisk.conf /etc/asterisk/asterisk.conf
COPY config/sip.conf /etc/asterisk/sip.conf
COPY config/extensions.conf /etc/asterisk/extensions.conf
COPY config/rtp.conf /etc/asterisk/rtp.conf

# Expose the SIP and RTP ports
EXPOSE 5060/udp
EXPOSE 10000-20000/udp

# Start Asterisk in foreground
CMD ["asterisk", "-f", "-vvv"]
