from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from database import engine, get_db
import models
import schemas


# =========================================================
# FASTAPI APP
# =========================================================

app = FastAPI(
    title="SmartOps AI API",
    description="Backend API for SmartOps AI Operations Platform",
    version="1.0.0",
)


# =========================================================
# CORS
# =========================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =========================================================
# DATABASE
# =========================================================

models.Base.metadata.create_all(bind=engine)


# =========================================================
# BASIC ROUTES
# =========================================================

@app.get("/")
def home():
    return {
        "message": "SmartOps AI Backend is running",
        "status": "success",
    }


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "service": "SmartOps AI API",
    }


# =========================================================
# DASHBOARD SUMMARY API
# =========================================================

@app.get(
    "/dashboard/summary",
    response_model=schemas.DashboardSummary,
)
def get_dashboard_summary(
    db: Session = Depends(get_db),
):
    total_orders = (
        db.query(models.Order)
        .filter(models.Order.is_active == True)
        .count()
    )

    completed_orders = (
        db.query(models.Order)
        .filter(
            models.Order.is_active == True,
            models.Order.status == "Completed",
        )
        .count()
    )

    pending_orders = (
        db.query(models.Order)
        .filter(
            models.Order.is_active == True,
            models.Order.status == "Pending",
        )
        .count()
    )

    active_workers = (
        db.query(models.Worker)
        .filter(models.Worker.is_active == True)
        .count()
    )

    low_stock_products = (
        db.query(models.Product)
        .filter(
            models.Product.is_active == True,
            models.Product.current_stock
            <= models.Product.minimum_stock,
        )
        .count()
    )

    return {
        "total_orders": total_orders,
        "completed_orders": completed_orders,
        "pending_orders": pending_orders,
        "active_workers": active_workers,
        "low_stock_products": low_stock_products,
    }


# =========================================================
# PRODUCT APIs
# =========================================================

@app.post(
    "/products",
    response_model=schemas.ProductResponse,
)
def create_product(
    product: schemas.ProductCreate,
    db: Session = Depends(get_db),
):
    existing_product = (
        db.query(models.Product)
        .filter(
            models.Product.product_id == product.product_id
        )
        .first()
    )

    if existing_product:
        raise HTTPException(
            status_code=400,
            detail="Product ID already exists",
        )

    new_product = models.Product(
        product_id=product.product_id,
        name=product.name,
        category=product.category,
        price=product.price,
        current_stock=product.current_stock,
        minimum_stock=product.minimum_stock,
    )

    db.add(new_product)
    db.commit()
    db.refresh(new_product)

    return new_product


@app.get(
    "/products",
    response_model=list[schemas.ProductResponse],
)
def get_products(
    db: Session = Depends(get_db),
):
    products = (
        db.query(models.Product)
        .all()
    )

    return products
# =========================================================
# DELETE PRODUCT API
# =========================================================

@app.delete("/products/{product_id}")
def delete_product(
    product_id: str,
    db: Session = Depends(get_db),
):
    product = (
        db.query(models.Product)
        .filter(
            models.Product.product_id == product_id
        )
        .first()
    )

    if not product:
        raise HTTPException(
            status_code=404,
            detail="Product not found",
        )

    # Soft delete: product record remains in the database.
    product.is_active = False

    db.commit()

    return {
        "status": "success",
        "message": "Product deleted successfully",
        "product_id": product_id,
    }

# =========================================================
# LOW STOCK API
# =========================================================

@app.get(
    "/products/low-stock",
    response_model=list[schemas.ProductResponse],
)
def get_low_stock_products(
    db: Session = Depends(get_db),
):
    products = (
        db.query(models.Product)
        .filter(
            models.Product.current_stock
            <= models.Product.minimum_stock
        )
        .all()
    )

    return products


# =========================================================
# AI INVENTORY RISK ANALYSIS API
# =========================================================

@app.get("/ai/stockout-prediction")
def predict_stockout_risk(
    db: Session = Depends(get_db),
):
    """
    Analyze inventory stock levels and provide risk insights.

    This is a rule-based inventory risk analysis,
    not a trained machine-learning prediction model.
    """

    products = (
        db.query(models.Product)
        .filter(models.Product.is_active == True)
        .all()
    )

    results = []

    for product in products:
        stock = product.current_stock
        minimum = product.minimum_stock

        # ---------------------------------------------
        # Determine Inventory Risk
        # ---------------------------------------------

        if stock <= minimum:
            risk_level = "High"

            recommendation = (
                f"Restock immediately. "
                f"Current stock is {stock} units."
            )

            suggested_restock = max(
                (minimum * 2) - stock,
                0,
            )

        elif stock <= minimum * 1.5:
            risk_level = "Medium"

            recommendation = (
                "Monitor stock closely and "
                "plan replenishment."
            )

            suggested_restock = max(
                (minimum * 2) - stock,
                0,
            )

        else:
            risk_level = "Low"

            recommendation = (
                "Stock is currently above "
                "the configured risk threshold."
            )

            suggested_restock = 0

        results.append({
            "product_id": product.product_id,
            "product_name": product.name,
            "current_stock": stock,
            "minimum_stock": minimum,
            "risk_level": risk_level,
            "suggested_restock_quantity": suggested_restock,
            "recommendation": recommendation,
        })

    return {
        "status": "success",
        "analysis_type": "Rule-based inventory risk analysis",
        "total_products_analyzed": len(results),

        "high_risk_products": sum(
            1
            for item in results
            if item["risk_level"] == "High"
        ),

        "medium_risk_products": sum(
            1
            for item in results
            if item["risk_level"] == "Medium"
        ),

        "low_risk_products": sum(
            1
            for item in results
            if item["risk_level"] == "Low"
        ),

        "predictions": results,
    }


# =========================================================
# WORKER APIs
# =========================================================

@app.post(
    "/workers",
    response_model=schemas.WorkerResponse,
)
def create_worker(
    worker: schemas.WorkerCreate,
    db: Session = Depends(get_db),
):
    existing_worker = (
        db.query(models.Worker)
        .filter(
            models.Worker.worker_id == worker.worker_id
        )
        .first()
    )

    if existing_worker:
        raise HTTPException(
            status_code=400,
            detail="Worker ID already exists",
        )

    new_worker = models.Worker(
        worker_id=worker.worker_id,
        name=worker.name,
        phone=worker.phone,
        location=worker.location,
        status=worker.status,
    )

    db.add(new_worker)
    db.commit()
    db.refresh(new_worker)

    return new_worker


@app.get(
    "/workers",
    response_model=list[schemas.WorkerResponse],
)
def get_workers(
    db: Session = Depends(get_db),
):
    workers = (
        db.query(models.Worker)
        .all()
    )

    return workers


# =========================================================
# WORKER STATUS UPDATE API
# =========================================================

@app.put(
    "/workers/{worker_id}/status",
    response_model=schemas.WorkerResponse,
)
def update_worker_status(
    worker_id: str,
    status_data: schemas.WorkerStatusUpdate,
    db: Session = Depends(get_db),
):
    worker = (
        db.query(models.Worker)
        .filter(
            models.Worker.worker_id == worker_id
        )
        .first()
    )

    if not worker:
        raise HTTPException(
            status_code=404,
            detail="Worker not found",
        )

    allowed_statuses = [
        "Available",
        "On Delivery",
        "Offline",
        "Unavailable",
    ]

    if status_data.status not in allowed_statuses:
        raise HTTPException(
            status_code=400,
            detail=(
                "Invalid worker status. Allowed statuses: "
                + ", ".join(allowed_statuses)
            ),
        )

    worker.status = status_data.status

    db.commit()
    db.refresh(worker)

    return worker


# =========================================================
# ORDER APIs
# =========================================================

@app.post(
    "/orders",
    response_model=schemas.OrderResponse,
)
def create_order(
    order: schemas.OrderCreate,
    db: Session = Depends(get_db),
):
    existing_order = (
        db.query(models.Order)
        .filter(
            models.Order.order_id == order.order_id
        )
        .first()
    )

    if existing_order:
        raise HTTPException(
            status_code=400,
            detail="Order ID already exists",
        )

    new_order = models.Order(
        order_id=order.order_id,
        customer_name=order.customer_name,
        delivery_address=order.delivery_address,
        location=order.location,
        marketplace=order.marketplace,
        total_amount=order.total_amount,
        status=order.status,
        assigned_worker=order.assigned_worker,
    )

    db.add(new_order)
    db.commit()
    db.refresh(new_order)

    return new_order


@app.get(
    "/orders",
    response_model=list[schemas.OrderResponse],
)
def get_orders(
    db: Session = Depends(get_db),
):
    orders = (
        db.query(models.Order)
        .all()
    )

    return orders


# =========================================================
# ORDER STATUS UPDATE API
# =========================================================

@app.put(
    "/orders/{order_id}/status",
    response_model=schemas.OrderResponse,
)
def update_order_status(
    order_id: str,
    status_data: schemas.OrderStatusUpdate,
    db: Session = Depends(get_db),
):
    order = (
        db.query(models.Order)
        .filter(
            models.Order.order_id == order_id
        )
        .first()
    )

    if not order:
        raise HTTPException(
            status_code=404,
            detail="Order not found",
        )

    allowed_statuses = [
        "Pending",
        "Assigned",
        "Out for Delivery",
        "Completed",
        "Failed",
        "Cancelled",
    ]

    if status_data.status not in allowed_statuses:
        raise HTTPException(
            status_code=400,
            detail=(
                "Invalid status. Allowed statuses: "
                + ", ".join(allowed_statuses)
            ),
        )

    order.status = status_data.status

    db.commit()
    db.refresh(order)

    return order


# =========================================================
# ORDER ASSIGNMENT API
# =========================================================

@app.put(
    "/orders/{order_id}/assign",
    response_model=schemas.OrderResponse,
)
def assign_order(
    order_id: str,
    assignment_data: schemas.OrderAssignmentUpdate,
    db: Session = Depends(get_db),
):
    order = (
        db.query(models.Order)
        .filter(
            models.Order.order_id == order_id
        )
        .first()
    )

    if not order:
        raise HTTPException(
            status_code=404,
            detail="Order not found",
        )

    worker = (
        db.query(models.Worker)
        .filter(
            models.Worker.worker_id
            == assignment_data.worker_id
        )
        .first()
    )

    if not worker:
        raise HTTPException(
            status_code=404,
            detail="Worker not found",
        )

    if worker.status != "Available":
        raise HTTPException(
            status_code=400,
            detail=(
                f"Worker {worker.worker_id} is currently "
                f"{worker.status} and cannot be assigned."
            ),
        )

    order.assigned_worker = worker.worker_id
    order.status = "Assigned"

    worker.status = "On Delivery"

    db.commit()
    db.refresh(order)

    return order