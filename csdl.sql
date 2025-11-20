-- -----------------------------
-- Bảng Product (sản phẩm)
-- -----------------------------
CREATE TABLE Product (
  product_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  image VARCHAR(255),
  category VARCHAR(20) NOT NULL DEFAULT 'Nước'
);

INSERT INTO Product (name, image, category) VALUES
  ('Cà phê đen', '/images/cafe_den.jpg', 'Nước'),
  ('Cà phê sữa', '/images/cafe_sua.jpg', 'Nước'),
  ('Trà sữa', '/images/tra_sua.jpg', 'Nước'),
  ('Bánh ngọt sô-cô-la', '/images/banh_ngot.jpg', 'Ăn kèm'),
  ('Bánh kem dâu', '/images/banh_kem_dau.jpg', 'Ăn kèm');

-- -----------------------------
-- Bảng Product_Size (size & giá)
-- -----------------------------
CREATE TABLE Product_Size (
  product_size_id INT AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL,
  size VARCHAR(10),
  price INT NOT NULL,
  FOREIGN KEY (product_id) REFERENCES Product(product_id)
);

INSERT INTO Product_Size (product_id, size, price) VALUES
  (1, 'S', 24000),
  (1, 'M', 30000),
  (1, 'L', 36000),
  (2, 'S', 28000),
  (2, 'M', 35000),
  (2, 'L', 42000),
  (3, 'S', 32000),
  (3, 'M', 40000),
  (3, 'L', 48000),
  (4, NULL, 25000),
  (5, NULL, 30000);

-- -----------------------------
-- Bảng Orders (đơn hàng)
-- -----------------------------
CREATE TABLE Orders (
  order_id INT AUTO_INCREMENT PRIMARY KEY,
  customer_name VARCHAR(100),
  total_amount INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO Orders (customer_name, total_amount, created_at) VALUES
  ('Nguyen Van A', 80000, '2025-10-06 09:30:00'),
  ('Tran Thi B', 78000, '2025-10-06 10:15:00'),
  ('Le Van C', 56000, '2025-10-05 14:00:00');

-- -----------------------------
-- Bảng Order_Product (chi tiết món)
-- -----------------------------
CREATE TABLE Order_Product (
  order_product_id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  product_size_id INT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  price INT NOT NULL,
  FOREIGN KEY (order_id) REFERENCES Orders(order_id),
  FOREIGN KEY (product_size_id) REFERENCES Product_Size(product_size_id)
);

INSERT INTO Order_Product (order_id, product_size_id, quantity, price) VALUES
  (1, 2, 1, 30000),
  (1, 4, 2, 25000),
  (2, 9, 1, 48000),
  (2, 11, 1, 30000),
  (3, 5, 2, 28000);

-- -----------------------------
-- Bảng User (nhân viên & chủ)
-- -----------------------------
CREATE TABLE User (
  user_id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  full_name VARCHAR(100) NOT NULL,
  role ENUM('Chủ','Nhân viên') NOT NULL DEFAULT 'Nhân viên',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO User (username, password, full_name, role) VALUES
  ('admin', 'hashed_password_here', 'Nguyen Van Chu', 'Chủ'),
  ('nv01', 'hashed_password_here', 'Tran Thi Nhan', 'Nhân viên'),
  ('nv02', 'hashed_password_here', 'Le Van A', 'Nhân viên');

-- -----------------------------
-- Bảng Salary (lương nhân viên)
-- -----------------------------
CREATE TABLE Salary (
  salary_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,            -- liên kết với User
  base_salary INT NOT NULL,        -- lương cơ bản
  bonus INT DEFAULT 0,             -- tiền thưởng
  allowance INT DEFAULT 0,         -- phụ cấp
  total_salary INT AS (base_salary + bonus + allowance) PERSISTENT, -- tổng lương
  effective_from DATE NOT NULL,    -- ngày áp dụng
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES User(user_id)
);

INSERT INTO Salary (user_id, base_salary, bonus, allowance, effective_from) VALUES
  (2, 5000000, 500000, 200000, '2025-10-01'),
  (3, 4500000, 300000, 150000, '2025-10-01');

-- -----------------------------
-- Bảng Schedule (thời khóa biểu)
-- -----------------------------
CREATE TABLE Schedule (
  schedule_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  work_date DATE NOT NULL,
  weekday TINYINT, -- 1=Thứ 2, ..., 7=Chủ nhật
  shift ENUM('Ca sáng','Ca chiều','Ca tối') NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES User(user_id)
);

INSERT INTO Schedule (user_id, work_date, weekday, shift) VALUES
  (2, '2025-10-08', 3, 'Ca sáng'),  -- 3 = Thứ 4
  (2, '2025-10-08', 3, 'Ca chiều'),
  (3, '2025-10-08', 3, 'Ca tối');

-- -----------------------------
-- Bảng Notification (thông báo)
-- -----------------------------
CREATE TABLE Notification (
  notification_id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO Notification (title, content) VALUES
  ('Họp nhân viên', 'Tất cả nhân viên có mặt lúc 9h sáng mai.'),
  ('Thông báo giảm giá', 'Ngày mai giảm 10% tất cả đồ uống.');
