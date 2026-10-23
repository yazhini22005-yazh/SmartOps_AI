from pydantic import BaseModel


# =========================================================
# PRODUCT SCHEMAS
# =========================================================

class ProductCreate(BaseModel):
    product_id: str
    name: str
    category: str
    price: float
    current_stock: int = 0
    minimum_stock: int = 10


class ProductResponse(BaseModel):
    id: int
    product_id: str
    name: str
    category: str
    price: float
    current_stock: int
    minimum_stock: int
    is_active: bool

    class Config:
        from_attributes = True


# =========================================================
# WORKER SCHEMAS
# =========================================================

class WorkerCreate(BaseModel):
    worker_id: str
    name: str
    phone: str
    location: str
    status: str = "Available"


class WorkerResponse(BaseModel):
    id: int
    worker_id: str
    name: str
    phone: str
    location: str
    status: str
    is_active: bool

    class Config:
        from_attributes = True


class WorkerStatusUpdate(BaseModel):
    status: str


# =========================================================
# ORDER SCHEMAS
# =========================================================

class OrderCreate(BaseModel):
    order_id: str
    customer_name: str
    delivery_address: str
    location: str
    marketplace: str
    total_amount: float
    status: str = "Pending"
    assigned_worker: str | None = None


class OrderResponse(BaseModel):
    id: int
    order_id: str
    customer_name: str
    delivery_address: str
    location: str
    marketplace: str
    total_amount: float
    status: str
    assigned_worker: str | None
    is_active: bool

    class Config:
        from_attributes = True


# =========================================================
# ORDER STATUS
# =========================================================

class OrderStatusUpdate(BaseModel):
    status: str


# =========================================================
# ORDER ASSIGNMENT
# =========================================================

class OrderAssignmentUpdate(BaseModel):
    worker_id: str


# =========================================================
# DASHBOARD SUMMARY
# =========================================================

class DashboardSummary(BaseModel):
    total_orders: int
    completed_orders: int
    pending_orders: int
    active_workers: int
    low_stock_products: int


# =========================================================
# PYDANTIC V2 MODEL REBUILD
# =========================================================

DashboardSummary.model_rebuild()