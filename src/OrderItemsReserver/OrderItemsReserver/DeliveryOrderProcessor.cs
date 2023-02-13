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
using System.Collections.Generic;
using Microsoft.Azure.Cosmos;
using System.Linq;
using System.Web.Http;

namespace OrderItemsReserver
{
    public static class DeliveryOrderProcessor
    {
        [FunctionName("DeliveryOrderProcessor")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            log.LogInformation("C# HTTP trigger function processed a request.");

            CosmosClient client = new(Environment.GetEnvironmentVariable("cosmosDbConnectionString"));
            Database database = await client.CreateDatabaseIfNotExistsAsync(Environment.GetEnvironmentVariable("cosmosDbDatabaseName"));
            Container container = await database.CreateContainerIfNotExistsAsync(
                Environment.GetEnvironmentVariable("cosmosDbContainerName"),
                Environment.GetEnvironmentVariable("cosmosDbPartitionKey")
            );

            var json = await req.ReadAsStringAsync();
            var order = JsonConvert.DeserializeObject<DeliveryInfo>(json);

            if (order != null)
            {
                try
                {
                    var response = await container.UpsertItemAsync(order, new PartitionKey(order.id));

                    var responseMessage = response != null && response.StatusCode == System.Net.HttpStatusCode.OK
                    ? "This HTTP triggered function executed successfully. Pass an order in the request body for a personalized response."
                    : $"Order was submitted. This HTTP triggered function executed successfully.";

                    return new OkObjectResult(responseMessage);
                }
                catch (Exception e)
                {
                    return new InternalServerErrorResult();
                }

            }

            return new NotFoundObjectResult(string.Empty);
        }
    }

    public class DeliveryInfo
    {
        public string id { get; set; }
        public string ShippingAddress { get; set; }
        public List<string> Items { get; set; }
        public decimal FinalPrice { get; set; }
    }
}
