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

namespace Warehouse
{
    public static class OrderItemsReserver
    {
        [FunctionName("OrderItemsReserver")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            var blobContainerClient = new BlobContainerClient(Environment.GetEnvironmentVariable("blobStorageConnectionString"), Environment.GetEnvironmentVariable("blobStorageContainerName"));

            var id = Guid.NewGuid().ToString();
            await blobContainerClient.UploadBlobAsync($"{id}.json", req.Body);

            string responseMessage = string.IsNullOrEmpty(id)
                ? "This HTTP triggered function executed successfully. Pass an order in the request body for a personalized response."
                : $"Order {id} was submitted. This HTTP triggered function executed successfully.";

            return new OkObjectResult(responseMessage);
        }
    }
}
