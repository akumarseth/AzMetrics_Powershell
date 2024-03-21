Connect-AzAccount

$ResourceGroups = @("Training-RG")

foreach ($ResourceGroup in $ResourceGroups)
{
    $DataToExport = @()
    Write-Output ("Showing resources in resource group " + $ResourceGroup)
     

    $SAs = Get-AzStorageAccount -ResourceGroupName $ResourceGroup
    foreach ($sa in $SAs)
    {
        $sa.StorageAccountName
        $sa.Id

        $MetricsDefinitions = Get-AzMetricDefinition -ResourceId $sa.Id
        $MetricsDefinitions
        foreach($metric in $MetricsDefinitions) {

            $MetricName = $metric.Name.Value
            #if ($MetricName -eq "Availability" -or $MetricName -eq "SuccessE2ELatency" -or $MetricName -eq "AverageMemoryWorkingSet" -or $MetricName -eq "MemoryWorkingSet")
            #{
            
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
                        
                        $MetricsDetails = Get-AzMetric -ResourceId $sa.Id -MetricName $metric.Name.Value -TimeGrain 00:15:00 -StartTime (Get-Date).AddDays(-1) -EndTime (Get-Date) -AggregationType $aggtype -WarningAction SilentlyContinue
                        
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
                    }

                    $totalRequests
                    $count
                    $maxRequests
                    $minRequests

                    try {
                        $avgRequests = $totalRequests / $count
                    } catch {
                        $avgRequests = 0
                    }
            
                    Write-Output ("*********************************************")

                    $metricsData = [PSCustomObject]@{
                        ResourceGroup = $ResourceGroup
                        ResourceName = $sa.StorageAccountName
                        Metricsname = $MetricName
                        Total = $totalRequests
                        Count = $count
                        Maximum = $maxRequests
                        Minimum = $minRequests
                        Average = $avgRequests
                        unit = $metric.Unit
                    }

                    $DataToExport += $metricsData
                #}

            }
        }
    }

    #$DataToExport

    $DataToExport | Export-Csv -Path C:\AZMetric_export\sa_$ResourceGroup.csv
    $DataToExport | Export-Excel -Path C:\AZMetric_export\sa_$ResourceGroup.xlsx
    
}
