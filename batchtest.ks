run once "test.ks".
set todolist to list().
todolist:add(list(3.5,3.25,3,2.75,2.5,2.25,2,1.75,1.5,1.25)).
todolist:add(list(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,22.5,25,30)).
 
function doublechomp{
    parameter file.
    set dat to readjson(file).
    if dat[1] >= todolist[1]:length{
        set dat[0] to dat[0]+1.
        set dat[1] to 0.
        writejson(dat,file).
    }
    if not (dat[0] >= todolist[0]:length){
        set result to list(todolist[0][dat[0]], todolist[1][dat[1]]).
        set dat[1] to dat[1] +1.
        writejson(dat,file).
        return result.
    }
    else return "empty".
   
}
 
set data to list().
set savefile to "launchdata.json".
set data to readjson(savefile).
 
print data.
set todo to doublechomp("todo.json").
if not (todo = "empty"){
    set testtwr to todo[0].
    set testpitch to todo[1].
 
    set results to launchtest(testtwr,testpitch).
    data:add(results).
    writejson(data,savefile).
    if not (results = 0)
        kuniverse:reverttolaunch().
    else{
        print "reached a failure point".
        set l to readjson("todo.json").
        set l[1] to 100.
        writejson(l,"todo.json").
        kuniverse:reverttolaunch().
    }
}
print "done.".
