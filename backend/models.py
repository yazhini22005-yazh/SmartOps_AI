from sqlalchemy import Column, Integer, String, Float, Boolean
from database import Base


# =========================================================
# PRODUCT
# =========================================================

class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)

    product_id = Column(
        String,
        unique=True,
        index=True,
        nullable=False
    )

    name = Column(String, nullable=False)

    category = Column(String, nullable=False)

    price = Column(Float, nullable=False)

    current_stock = Column(
        Integer,
        nullable=False,
        default=0
    )

    minimum_stock = Column(
        Integer,
        nullable=False,
        default=10
    )

    is_active = Column(
        Boolean,
        default=True
    )


# =========================================================
# WORKER
# =========================================================

class Worker(Base):
    __tablename__ = "workers"

    id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    worker_id = Column(
        String,
        unique=True,
        index=True,
        nullable=False
    )

    name = Column(
        String,
        nullable=False
    )

    phone = Column(
        String,
        nullable=False
    )

    location = Column(
        String,
        nullable=False
    )

    status = Column(
        String,
        default="Available"
    )

    is_active = Column(
        Boolean,
        default=True
    )


# =========================================================
# ORDER
# =========================================================

class Order(Base):
    __tablename__ = "orders"

    id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    order_id = Column(
        String,
        unique=True,
        index=True,
        nullable=False
    )

    customer_name = Column(
        String,
        nullable=False
    )

    delivery_address = Column(
        String,
        nullable=False
    )

    location = Column(
        String,
        nullable=False
    )

    marketplace = Column(
        String,
        nullable=False
    )

    total_amount = Column(
        Float,
        nullable=False
    )

    status = Column(
        String,
        default="Pending"
    )

    assigned_worker = Column(
        String,
        nullable=True
    )

    is_active = Column(
        Boolean,
        default=True
    )