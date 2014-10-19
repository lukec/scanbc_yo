FROM kazeburo/perl-build
RUN perl-build 5.20.1 /opt/perl/
RUN echo 'export PATH=/opt/perl/bin:$PATH' > /etc/profile.d/xbuild-perl.sh
ENV PATH /opt/perl/bin:${PATH}
RUN curl -L http://cpanmin.us | perl - App::cpanminus
RUN mkdir /opt/scanbc_yo
RUN apt-get update
RUN apt-get install --yes libssl-dev
RUN cpanm --notest Net::Twitter YAML autodie Try::Tiny DateTime
WORKDIR /opt/scanbc_yo
ADD scanbc_yo.pl /opt/scanbc_yo/
CMD perl scanbc_yo.pl
