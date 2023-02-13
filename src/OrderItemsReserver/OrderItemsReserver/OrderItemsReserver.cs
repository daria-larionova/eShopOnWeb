using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System;
using Azure.Storage.Blobs;
using System.Text;
using Newtonsoft.Json.Linq;
using Azure.Core;
using System.Net.Http;

namespace OrderItemsReserver
{
    public class OrderItemsReserver
    {
        [FunctionName("OrderItemsReserver")]
        public static async Task Run([ServiceBusTrigger("orders", "function-app-subscription", Connection = "serviceBusConnectionString")]string myQueueItem, string messageId, ILogger log)
        {
            try
            {
                log.LogInformation("C# HTTP trigger function processed a request.");

                //Throw exception for testing LogicApp
                //throw new Exception();

                log.LogInformation("1.");
                var blobOptions = new BlobClientOptions()
                {
                    Retry = {
                    Delay = TimeSpan.FromSeconds(2),
                    MaxRetries = 3,
                    Mode = RetryMode.Exponential,
                    MaxDelay = TimeSpan.FromSeconds(10),
                    NetworkTimeout = TimeSpan.FromSeconds(100)
                },
                };
                log.LogInformation("2.");
                var blobContainerClient = new BlobContainerClient(Environment.GetEnvironmentVariable("blobStorageConnectionString"), Environment.GetEnvironmentVariable("blobStorageContainerName"), blobOptions);

                log.LogInformation("3.");
                await blobContainerClient.UploadBlobAsync($"{messageId}.json", new MemoryStream(Encoding.UTF8.GetBytes(myQueueItem ?? string.Empty)));

                string responseMessage = string.IsNullOrEmpty(messageId)
                    ? "This HTTP triggered function executed successfully. Pass an order in the request body for a personalized response."
                    : $"Message {messageId} was submitted. This HTTP triggered function executed successfully.";
            }
            catch (Exception e)
            {
                var client = new HttpClient();
                await client.PostAsJsonAsync(Environment.GetEnvironmentVariable("logicAppEndpoint"), new object());
            }
        }
    }
}
