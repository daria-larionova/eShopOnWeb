using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore;
using Microsoft.eShopWeb.Web.Configuration;
using Microsoft.eShopWeb.Web.Interfaces;

namespace Microsoft.eShopWeb.Web.Services;

public class WarehouseService : IWarehouseService
{
    public async Task ReserveItems(Order order)
    {
        var client = new HttpClient();
        await client.PostAsJsonAsync("https://<function app name>.azurewebsites.net/api/OrderItemsReserver", order);
    }
}
