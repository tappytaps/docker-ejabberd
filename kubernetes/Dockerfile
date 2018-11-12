###################################################################
####That image purpose is to prepare the final image to use with
###################################################################

#That images as built from the Source directory.
FROM rroemhild/ejabberd:latest

ENV EJABBERD_USER=ejabberd \
    EJABBERD_HOME=/opt/ejabberd \
    EJABBERD_DEFAULT_DB=mnesia \
    EJABBERD_SKIP_MODULES_UPDATE=true \
    EJABBERD_LOGLEVEL=4 \
    EJABBERD_DEBUG_MODE=true \
    #Set default locale for the environment
    LC_ALL=C.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

USER root

###########################################################################################

RUN mkdir -p $EJABBERD_HOME/scripts/cluster

COPY ./scripts/cluster/100_ejabberd_join_cluster.sh $EJABBERD_HOME/scripts/cluster/100_ejabberd_join_cluster.sh

COPY ./scripts/lib/base_functions.sh $EJABBERD_HOME/scripts/lib/base_functions.sh
COPY ./scripts/lib/functions.sh $EJABBERD_HOME/scripts/lib/functions.sh


ADD ./run.sh /sbin/run

##SWITCH BACK TO EJABBERD USER

RUN chown -R $EJABBERD_USER:$EJABBERD_USER $EJABBERD_HOME

RUN chmod +x /sbin/run
RUN chmod +x $EJABBERD_HOME/scripts/cluster/100_ejabberd_join_cluster.sh
RUN chmod +x $EJABBERD_HOME/scripts/lib/base_functions.sh
RUN chmod +x $EJABBERD_HOME/scripts/lib/functions.sh

USER $EJABBERD_USER

WORKDIR $EJABBERD_HOME

EXPOSE 4560 5222 5269 5280 5443 4369 4200 4201 4202 4203 4204 4205 4205 4206 4207 4208 4209 4210

VOLUME ["./home:/opt/ejabberd/"]

CMD ["start"]

ENTRYPOINT ["run"]
