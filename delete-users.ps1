param([string]$orgurl , [string]$apikey, [string]$filepath)


$baseUri = $orgurl + "/api/v1/users/"
$authorizationHeader = "SSWS " + $apikey


New-Item "Logs" -type directory


function ExportToCsv($file, $login, $message)
{

        $fileData = @{
         Username = $login
         Message = $message
        }

        $row = New-Object PSObject -Property $fileData
        $result += $row
        


        $logFile ="Logs\" + $file 
        $result | Out-File -Append $logFile 


}

function WebRequest($uri, $reqType)
{
    $headers = @{}
	$headers["Authorization"] = $authorizationHeader
	$headers["Accept"] = "application/json"
	$headers["Content-Type"] = "application/json"

    $returnObject = ""

     try
     {
        $response = Invoke-WebRequest -Method $reqType -Uri $uri -Headers $headers
        
        $returnObject = $response
       
    }
    catch
    {
        Write-Host $_.Exception.Message 

        Write-Host "`n"

        $returnObject = "Error"
    }

    return $returnObject


}

function GetUsers($login)
{
   
    $loginString = [string]$login

	$uri = $baseUri + $loginString

    $response = WebRequest $uri "Get"

    if ($response -ne "Error")
    {
        
        $user = ConvertFrom-Json $response.Content

        $id =  [string]$user.id

        $username =  [string]$user.profile.login

        $status = [string]$user.status
    

        if ($status -eq "DEPROVISIONED")
        {

            Write-Host "User is Deprovisioned Already `n"
            ExportToCsv "deprov-users.csv" $username "User Was Deprovisioned"
           
            $delUserUri = $baseUri + $id 

            $response = WebRequest $delUserUri "Delete"

            if($response.StatusCode -eq 204)
            {  
                Write-Host "User Deleted Successfully `n"
                ExportToCsv "deprov-users-deleted.csv" $username "Deprovisioned User Deleted Successfully"
            }
            else
            {
              Write-Host "Deletign User Failed `n"
                ExportToCsv "deprov-users-deletion-failed.csv" $username "Deleting Deprovisioned Failed"  
            }

        }
        else
        {
            ExportToCsv "active-users.csv" $username "User Was Active"

            $deprovisionUri = $baseUri + $id + "/lifecycle/deactivate"

            $response = WebRequest $deprovisionUri "Post"

            if($response -ne "Error")
            {
                Write-Host "User Deprovisioned Successsfully `n"
                ExportToCsv "active-users-deprovisioned.csv" $username "Active User Deactivated Successfully"

                $delUserUri = $baseUri+ $id 

                $response = WebRequest $delUserUri "Delete"

                if($response.StatusCode -eq 204)
                {    
                    Write-Host "User Deleted Successfully `n"
                    ExportToCsv "active-users-deprovisioned-deleted.csv" $username "Active User Deactivated and Deleted Successfully"
                }
                else
                {
                    Write-Host "Deleting User Failed `n"
                    ExportToCsv "active-users-deprovisioned-deletion-failed.csv" $username "Deleting Deprovisioned (from Active) Failed"  
                }

            }
            else
            {
                Write-Host "Deactivating User Failed `n"
                ExportToCsv "active-users-deprovisioning-failed.csv" $username "Deactivating User Failed"
            }

        }
    }
    else
    {
        ExportToCsv "not-found-users.csv" $login "User Not Found in Org"
        Write-Host "Error Occured While Executing Request `n"
    }
 
}


function ReadCsv()
{

    Import-Csv $filepath | 
    ForEach-Object {

        $login = $_.login

        Write-Host $login + " Will be deleted `n"

        GetUsers $login

    }

}


ReadCsv

