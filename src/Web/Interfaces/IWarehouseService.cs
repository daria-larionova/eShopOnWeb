using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;

namespace Microsoft.eShopWeb.Web.Interfaces;

public interface IWarehouseService
{
    Task ReserveItems(Order order);

    Task DeliveryOrder(Order order);
}
