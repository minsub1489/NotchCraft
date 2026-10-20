#!/usr/bin/env python3
"""Deterministic local protocol fixture. Does not run an AI or access user data."""
import sys, json
quota_reads = 0

def emit(value):
    sys.stdout.write(json.dumps(value) + '\n')
    sys.stdout.flush()

for line in sys.stdin:
    request=json.loads(line)
    method=request.get('method')
    rid=request.get('id')
    if method=='initialize': result={'userAgent':'notchcraft-test-fixture'}
    elif method=='initialized': continue
    elif method=='thread/list': result={'data':[{'id':'external-history','name':'Fixture history','cwd':'/tmp','updatedAt':1800000000}],'nextCursor':None}
    elif method=='account/rateLimits/read':
        quota_reads += 1
        result={'rateLimits':{'primary':{'usedPercent':24+quota_reads,'windowDurationMins':300,'resetsAt':1800003600}}}
    elif method=='thread/start':
        if request['params']['sandbox'] not in ['read-only','workspace-write'] or request['params']['approvalPolicy']!='untrusted':
            emit({'id':rid,'error':{'code':-1,'message':'Invalid safety policy'}}); continue
        result={'thread':{'id':'owned-thread'},'model':'fixture-model'}
    elif method=='turn/start':
        emit({'method':'account/rateLimits/updated','params':{'rateLimits':{'limitId':'codex','primary':{'usedPercent':27,'windowDurationMins':300},'secondary':{'usedPercent':10,'windowDurationMins':10080}}}})
        emit({'id':rid,'result':{'turn':{'id':'owned-turn','status':'inProgress'}}})
        emit({'method':'turn/started','params':{'threadId':'owned-thread','turn':{'id':'owned-turn'}}})
        emit({'method':'item/started','params':{'threadId':'owned-thread','turnId':'owned-turn','item':{'id':'tool1','type':'commandExecution','command':'swift test'}}})
        emit({'id':'approval1','method':'item/commandExecution/requestApproval','params':{'threadId':'owned-thread','turnId':'owned-turn','command':'swift test'}})
        continue
    elif method=='turn/interrupt': result={}
    elif method is None and rid=='approval1':
        emit({'method':'serverRequest/resolved','params':{'threadId':'owned-thread','requestId':'approval1'}})
        emit({'method':'turn/completed','params':{'threadId':'owned-thread','turn':{'id':'owned-turn','status':'interrupted'}}})
        continue
    else:
        emit({'id':rid,'error':{'code':-32601,'message':'Not supported by fixture'}}); continue
    emit({'id':rid,'result':result})
