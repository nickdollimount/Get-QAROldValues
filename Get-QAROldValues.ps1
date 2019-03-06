[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]$ARServerFQDN,
    [Parameter(Mandatory=$True)]$OperationID
)

function GenericSqlQuery ($Server, $Database, $SQLQuery) {
    $Connection = New-Object System.Data.SQLClient.SQLConnection
    $Connection.ConnectionString = "server='$Server';database='$Database';trusted_connection=true;"
    $Connection.Open()
    $Command = New-Object System.Data.SQLClient.SQLCommand
    $Command.Connection = $Connection
    $Command.CommandText = $SQLQuery
    $Reader = $Command.ExecuteReader()
    while ($Reader.Read()) {
         $Reader.GetValue($1)
    }
    $Connection.Close()
}

function FetchOldValue($_MHSQLAlias, $_MHDatabaseName, $_OperationID){
    $SQLQuery = $("select data from [" + `
    $_MHDatabaseName + "].[dbo].[WfSharedOperations] inner join [" + `
    $_MHDatabaseName + "].[dbo].[WfOperationValues] on [" + $_MHDatabaseName + "].[dbo].[WfSharedOperations].guid = [" + `
    $_MHDatabaseName + "].[dbo].[WfOperationValues].operation where [" + `
    $_MHDatabaseName + "].[dbo].[WfOperationValues].value_short = '" + $_OperationID + "'")

    [xml] $xmlResults = GenericSqlQuery $_MHSQLAlias $_MHDatabaseName $SQLQuery
    $oldValues = $xmlResults.Operation.PreviousAttributes.PreviousAttribute

    $oldValuesObject = @()

    $oldValues | ForEach-Object{
        $properties = [ordered]@{
            "Attribute" = $_.name
            "Old Value" = $_.values.value
        }
    $tempObject = New-Object PSObject -Property $properties
    $oldValuesObject += $tempObject
    }

    return $oldValuesObject
}

function Main($_ARServerFQDN, $_OperationID){
    Connect-QADService -Service $_ARServerFQDN -Proxy | Out-Null

    $ARService = Get-QADObject -SearchRoot "Configuration/Server Configuration/Administration Services" `
        -DontUseDefaultIncludedProperties `
        -IncludedProperties edsaMHSQLAlias,edsaMHDatabaseName,edsaEdmServiceComputerName `
        -Type edsARService | Where-Object{$_.edsaEdmServiceComputerName -eq $_ARServerFQDN}

    FetchOldValue $ARService.edsaMHSQLAlias $ARService.edsaMHDatabaseName $_OperationID $_AttributeName
}

Main $ARServerFQDN $OperationID
