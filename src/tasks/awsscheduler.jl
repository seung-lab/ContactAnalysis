# include("../SimpleTasks.jl")

module AWSScheduler

using SimpleTasks.Types
using SimpleTasks.Services.AWSQueue
using SimpleTasks.Services.CLIBucket
# using SimpleTasks.Services.AWSCLIProvider
using ContactAnalysis.CountEdgesTask

import AWS
import JSON
import SimpleTasks.Services.Bucket
import SimpleTasks.Services.Queue
import SimpleTasks.Tasks.BasicTask

function schedule_count_edges(args...; queue_name="")
    env = AWS.AWSEnv()
    queue = AWSQueueService(env, queue_name)
    task = CountEdgesTask.CountEdgesTaskDetails(args...)
    # {"segmentation_storage":"in","slices":[[1,2],[3,4],[5,6]],"scale_idx":1,"output_storage":"out"}
    Queue.push_message(queue; message_body = JSON.json(task));
end

end # module AWSScheduler