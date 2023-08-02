FILE_NAME=pods.yaml
COPY_DIR=outdir
RESULT_DIR=raw-http
POD_TEMPLATE=pod-template.yaml
NS=openshift-compliance

PVC_CP=`oc get pvc -n openshift-compliance | awk 'NR>1 {print $1}'`

mkdir -p $COPY_DIR
mkdir -p $RESULT_DIR

for i in $PVC_CP;
do
  sed "s/<pvc>/$i/g" $POD_TEMPLATE >> $FILE_NAME;
  echo '---'>> $FILE_NAME;
done;

oc apply -f $FILE_NAME -n $NS

for i in $PVC_CP;
do
  while [[ $(oc get pods pv-extract-$i -n $NS  -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    sleep 2;
    echo "waiting pod Running - $i";
  done;
  oc cp pv-extract-$i:/workers-scan-results -n $NS ./$COPY_DIR/
done;

cd outdir
ls -al
TG_DIR=`ls -al | awk 'NR>1 {print $9}' | grep -E '[0-9]+' | sort -nr | head -1`
cd $TG_DIR
TG_FILE=`ls | grep '.bzip2'`
for i in $TG_FILE;
do
  oscap xccdf generate report $i > ../../$RESULT_DIR/$i.html
done;

echo "DELETE $FILE_NAME\n"
rm -rf ../../$FILE_NAME
rm -rf ../../$COPY_DIR

GET_POD=`oc get pod -n $NS | grep pv-extract | awk '{print $1}'`

echo "DELETE PODs\n"
for i  in $GET_POD;
do
  oc delete pod $i -n $NS --force;
done;
