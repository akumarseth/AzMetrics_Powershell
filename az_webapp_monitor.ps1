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
        Write-Output ("WebApp Details is " + $WebApp.Id + " " + $WebApp.Name + " " + $WebApp.State)

        Write-Output ("metrics for WebApp " + $WebApp.Name + " is ")  

        $MetricsDefinitions = Get-AzMetricDefinition -ResourceId $WebApp.Id

        foreach($metric in $MetricsDefinitions) {
            $MetricName=$metric.Name.Value
            $MetricName
            #if ($MetricName -eq "CpuTime" -or $MetricName -eq "Requests" -or $MetricName -eq "HealthCheckStatus")
            if ($MetricName -eq "CpuTime" -or $MetricName -eq "Requests" -or $MetricName -eq "AverageMemoryWorkingSet" -or $MetricName -eq "MemoryWorkingSet")
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
                        $MetricsDetails = Get-AzMetric -ResourceId $WebApp.Id -MetricName $metric.Name.Value -TimeGrain 00:15:00 -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) -AggregationType $aggtype -WarningAction SilentlyContinue

                        #$MetricsDetails.Data

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
                    ResourceName = $WebApp.Name
                    State = $WebApp.State
                    Metricsname = $MetricName
                    Total = $totalRequests
                    Count = $count
                    Maximum = $maxRequests
                    Minimum = $minRequests
                    Average = $avgRequests
                    unit = $metric.Unit
                }

                $DataToExport += $metricsData

            }

        }
    }

    $DataToExport | Export-Csv -Path C:\AZMetric_export\webapp_$ResourceGroup.csv
    $DataToExport | Export-Excel -Path C:\AZMetric_export\webapp_$ResourceGroup.xlsx
}
