if [ -e /usr/libexec/java_home ]; then
    export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home)}"
fi
