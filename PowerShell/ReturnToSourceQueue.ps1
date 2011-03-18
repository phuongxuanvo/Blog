##############################################################################################
## ReturnToSourceQueue.ps1 -- Return error messages to the source queue to replay
##
## Parameters:
##
##      [String] src_qname
##          Specifies the name of the error queue to replay.
##          
##
##      Example:
##          ReturnToSourceQueue comm_errors@TST-MSMQ-01
##############################################################################################


param([string]$src_qname)

New-Variable -Option constant -Name FAILEDQ -Value "FailedQ"

function Main
{

    if ( [System.String]::IsNullOrEmpty($src_qname) )
    {
        write-host "You must provide a source queue name"
        exit
    }

    [Reflection.Assembly]::LoadWithPartialName("System.Messaging") | out-null
   
    $src_q = new-object System.Messaging.MessageQueue(GetFullPath $src_qname)

    $msgs = $src_q.GetAllMessages()
    $count = $msgs.Length

    for( $i = 0; $i -lt $count; $i++ ) 
    {
        $msg = $src_q.Receive()
        
        # Determine the original source queue
        if ([System.String]::IsNullOrEmpty($msg))
        {
            return null
        }
        if (!$msg.Label.Contains($FAILEDQ))
        {
            return null
        }
        
        $dest_qname = GetFailedQueue($msg)
        
        $dest_q = new-object System.Messaging.MessageQueue(GetFullPath $dest_qname)
        
        $msg.Label = GetLabelWithoutFailedQueue($msg)
        
        $dest_q.Send( $msg, [System.Messaging.MessageQueueTransactionType]::Single )   
    }
        
    exit
}

# Returns the Full Path of queue
function GetFullPath ($value)
{
    $strArray = $value.Split("@")
    $machineName = $strArray[1]
    $queueName = $strArray[0]
    
    $fullPath = [System.String]::Format("formatname:DIRECT=OS:{0}\private$\{1}",$machineName,$queueName)   
    
    return $fullPath
}

# Return source queue name from NServiceBus failed queue element
function GetFailedQueue ($message)
{
    $startIndex = ($message.Label.IndexOf([System.String]::Format("<{0}>", $FAILEDQ)) + $FAILEDQ.Length) + 2
    $length = $message.Label.IndexOf([System.String]::Format("</{0}>", $FAILEDQ)) - $startIndex
    
    return $message.Label.Substring($startIndex, $length)
}

# Return message label with NServiceBus failed queue element removed
function GetLabelWithoutFailedQueue ($message)
{
    $index = $message.Label.IndexOf([System.String]::Format("<{0}>", $FAILEDQ))
    $num2 = $message.Label.IndexOf([System.String]::Format("</{0}>", $FAILEDQ)) + $FAILEDQ.Length + 3
    
    return $message.Label.Remove($index, $num2 - $index)
}

. Main