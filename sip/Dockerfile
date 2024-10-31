# Base image
FROM andrius/asterisk

# Copy configuration files
COPY asterisk.conf /etc/asterisk/asterisk.conf
COPY sip.conf /etc/asterisk/sip.conf
COPY extensions.conf /etc/asterisk/extensions.conf
COPY rtp.conf /etc/asterisk/rtp.conf

# Expose the SIP and RTP ports
EXPOSE 5060/udp
EXPOSE 10000-20000/udp

# Start Asterisk in foreground
CMD ["asterisk", "-f", "-vvv"]
