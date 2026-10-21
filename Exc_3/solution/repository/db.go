package repository

import (
	"time"

	"ordersystem/model"
)

type DatabaseHandler struct {
	drinks []model.Drink
	orders []model.Order
}

func NewDatabaseHandler() *DatabaseHandler {
	drinks := []model.Drink{
		{ID: 1, Name: "Coffee", Price: 2.50, Description: "Freshly brewed coffee"},
		{ID: 2, Name: "Tea", Price: 2.00, Description: "Hot tea"},
		{ID: 3, Name: "Water", Price: 1.50, Description: "Still mineral water"},
		{ID: 4, Name: "Orange Juice", Price: 3.00, Description: "Fresh orange juice"},
	}

	orders := []model.Order{
		{DrinkID: 1, CreatedAt: time.Now(), Amount: 2},
		{DrinkID: 2, CreatedAt: time.Now(), Amount: 1},
		{DrinkID: 1, CreatedAt: time.Now(), Amount: 3},
	}

	return &DatabaseHandler{
		drinks: drinks,
		orders: orders,
	}
}

func (db *DatabaseHandler) GetDrinks() []model.Drink {
	return db.drinks
}

func (db *DatabaseHandler) GetOrders() []model.Order {
	return db.orders
}

func (db *DatabaseHandler) GetTotalledOrders() map[uint64]uint64 {
	totalledOrders := make(map[uint64]uint64)

	for _, order := range db.orders {
		totalledOrders[order.DrinkID] += uint64(order.Amount)
	}

	return totalledOrders
}
func (db *DatabaseHandler) AddOrder(order *model.Order) {
	if order.CreatedAt.IsZero() {
		order.CreatedAt = time.Now()
	}

	db.orders = append(db.orders, *order)
}
