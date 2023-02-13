using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore;
using Microsoft.eShopWeb.Web.Configuration;
using Microsoft.eShopWeb.Web.Interfaces;
using Azure.Messaging.ServiceBus;
using System.Text.Json;

namespace Microsoft.eShopWeb.Web.Services;

public class WarehouseService : IWarehouseService
{
    private readonly IConfiguration _configuration;
    public WarehouseService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public async Task DeliveryOrder(Order order)
    {
        var client = new HttpClient();
        await client.PostAsJsonAsync(_configuration["DevliveryOrderFunctionUrl"], new
        {
            id = order.Id.ToString(),
            ShippingAddress = string.Join(", ", order.ShipToAddress?.Street, order.ShipToAddress?.City, order.ShipToAddress?.State, order.ShipToAddress?.Country),
            FinalPrice = order.Total(),
            Items = order.OrderItems?.Select(i => i.Id.ToString()).ToList()
        });
    }

    public async Task ReserveItems(Order order)
    {
        string QueueName = "orders";

        await using ServiceBusClient client = new ServiceBusClient(_configuration["ServiceBusConnectionString"]);
        ServiceBusSender sender = client.CreateSender(QueueName);

        string jsonEntity = JsonSerializer.Serialize(new
        {
            id = order.Id.ToString(),
            ShippingAddress = string.Join(", ", order.ShipToAddress?.Street, order.ShipToAddress?.City, order.ShipToAddress?.State, order.ShipToAddress?.Country),
            FinalPrice = order.Total(),
            Items = order.OrderItems?.Select(i => i.Id.ToString()).ToList()
        });
        ServiceBusMessage serializedContents = new ServiceBusMessage(jsonEntity);
        await sender.SendMessageAsync(serializedContents);
    }
}
