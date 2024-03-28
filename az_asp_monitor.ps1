Connect-AzAccount

$ResourceGroups = @("Training-RG")

foreach ($ResourceGroup in $ResourceGroups)
{
    $DataToExport = @()
    Write-Output ("Showing resources in resource group " + $ResourceGroup)

    $WebApps = Get-AzWebApp -ResourceGroupName $ResourceGroup
    Write-Output ("App Services in $ResourceGroup")
    
    foreach ($WebApp in $WebApps)
    {
        $AspPlanName = $WebApp.ServerFarmId
        $AspPlanName

        $MetricsDefinitions = Get-AzMetricDefinition -ResourceId $WebApp.ServerFarmId
        
        foreach ($metric in $MetricsDefinitions)
        {
            $MetricName = $metric.Name.Value

            if ($MetricName -eq "CpuPercentage" -or $MetricName -eq "MemoryPercentage")
            {
                Write-Output ("******************")
            
                Write-Output ("Metric name is " + $metric.Name.Value)
                Write-Output ("Metric supported AggregationType is " + $metric.SupportedAggregationTypes)
                Write-Output ("Primary AggregationType is " + $metric.PrimaryAggregationType)
                Write-Output ("Unit for AggregationType is " + $metric.Unit)

                $totalRequests=0
                $count=0
                $maxRequests=0
                $minRequests=0
                $avgRequests=0

                foreach($aggtype in $metric.SupportedAggregationTypes) 
                {
                    Write-Output ("********$aggtype**********")

                    if ($aggtype -ne "None") 
                    {
                        $MetricsDetails = Get-AzMetric -ResourceId $WebApp.ServerFarmId -MetricName $metric.Name.Value -TimeGrain 00:15:00 -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) -AggregationType $aggtype -WarningAction SilentlyContinue
                        #$MetricsDetails.Data
                        $file_name = "ASP_$aggtype" + "_$ResourceGroup.json"

                        $MetricsDetails.Data | ConvertTo-Json -depth 100 | Out-File "C:\AZMetric_export\$file_name"
                        
                        if ($MetricsDetails.Count -gt 0) 
                        {

                            if ($aggtype -eq "Total")
                            {
                                foreach ($dataPoint in $MetricsDetails.Data) {
                                    $totalRequests += $dataPoint.Total
                                }
                             }
                    
                            if ($aggtype -eq "Count")
                            {
                                foreach ($dataPoint in $MetricsDetails.Data) {
                                    $count += $dataPoint.Count
                                }
                            }
                   
                            if ($aggtype -eq "Maximum")
                            {
                                $maxRequests = ($MetricsDetails.Data | Measure-Object Maximum -Maximum).Maximum
                            }
                    
                            if ($aggtype -eq "Minimum")
                            {
                                $minRequests = ($MetricsDetails.Data | Measure-Object Minimum -Minimum).Minimum
                            }
                    
                        }
                        else 
                        {
                            Write-Host "No metric data available for the last 1 days."
                        }
                    }
                }

                Write-Output "Total Requests: $totalRequests"
                Write-Output "Count: $count"
                Write-Output "Max Requests: $maxRequests"
                Write-Output "Min Requests: $minRequests"
                try {
                    $avgRequests = $totalRequests / $count
                } catch {
                    $avgRequests = 0
                }
            
                Write-Output ("*********************************************")

                $metricsData = [PSCustomObject]@{
                    ResourceGroup = $ResourceGroup
                    WebAppName = $WebApp.Name
                    ResourceName = $WebApp.ServerFarmId
                    State = $WebApp.State
                    Metricsname = $MetricName
                    Total = $totalRequests
                    Count = $count
                    Maximum = $maxRequests
                    Minimum = $minRequests
                    Average = $avgRequests
                    unit = $metric.Unit
                    TimeStamp = Get-Date
                }

                $DataToExport += $metricsData
            }
        }
    }

    #$DataToExport | Export-Csv -Path C:\AZMetric_export\ASP_$ResourceGroup.csv
    $DataToExport | Export-Excel -Path C:\AZMetric_export\ASP_$ResourceGroup.xlsx
}