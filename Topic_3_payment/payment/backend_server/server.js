const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;
const SEPAY_API_KEY = process.env.SEPAY_API_KEY || 'sepay_api_key_test_123456';
const BANK_ACCOUNT = process.env.BANK_ACCOUNT || '31454997';
const BANK_NAME = process.env.BANK_NAME || 'ACB';
const ORDER_EXPIRE_MINUTES = parseInt(process.env.ORDER_EXPIRE_MINUTES || '5', 10);

// In-memory data store for Orders and Webhook Transaction IDs (Idempotency)
// order structure: { orderCode, amount, status: 'pending'|'paid'|'expired', createdAt: Date, overpaid: boolean, notes: String, actualPaidAmount: Number }
const orders = new Map();
const processedTransactions = new Set();

// Helper: Generate Order Code (Format: DH + 8 uppercase alphanumeric characters)
function generateOrderCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = 'DH';
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

// Helper: Check and update order expiration dynamically
function checkAndUpdateExpiration(order) {
  if (order.status === 'pending') {
    const elapsedMinutes = (Date.now() - new Date(order.createdAt).getTime()) / 60000;
    if (elapsedMinutes > ORDER_EXPIRE_MINUTES) {
      order.status = 'expired';
      order.notes = `Hết hạn thanh toán sau ${ORDER_EXPIRE_MINUTES} phút.`;
    }
  }
  return order;
}

// 1. POST /api/orders - Create a pending order
app.post('/api/orders', (req, res) => {
  const { amount } = req.body;
  if (!amount || isNaN(amount) || Number(amount) <= 0) {
    return res.status(400).json({ error: 'Số tiền không hợp lệ. Vui lòng nhập số lớn hơn 0.' });
  }

  const orderCode = generateOrderCode();
  const newOrder = {
    orderCode,
    amount: Number(amount),
    status: 'pending',
    createdAt: new Date(),
    overpaid: false,
    notes: '',
    actualPaidAmount: 0
  };

  orders.set(orderCode, newOrder);
  console.log(`[Order] Đã tạo đơn mới: ${orderCode} - Số tiền: ${amount}đ`);

  res.status(201).json({
    orderCode: newOrder.orderCode,
    amount: newOrder.amount,
    status: newOrder.status,
    createdAt: newOrder.createdAt,
    bankAccount: BANK_ACCOUNT,
    bankName: BANK_NAME
  });
});

// 2. GET /api/orders/:orderCode - Get details of an order
app.get('/api/orders/:orderCode', (req, res) => {
  const { orderCode } = req.params;
  const upperCode = orderCode.toUpperCase();
  const order = orders.get(upperCode);

  if (!order) {
    return res.status(404).json({ error: 'Không tìm thấy đơn hàng.' });
  }

  // Check and update expiration state dynamically
  const updatedOrder = checkAndUpdateExpiration(order);

  res.json({
    orderCode: updatedOrder.orderCode,
    amount: updatedOrder.amount,
    status: updatedOrder.status,
    createdAt: updatedOrder.createdAt,
    overpaid: updatedOrder.overpaid,
    notes: updatedOrder.notes,
    actualPaidAmount: updatedOrder.actualPaidAmount,
    bankAccount: BANK_ACCOUNT,
    bankName: BANK_NAME
  });
});

// 3. POST /api/webhooks/sepay - Receive webhook from SePay
app.post('/api/webhooks/sepay', (req, res) => {
  console.log('[Webhook] Nhận request SePay Webhook:', JSON.stringify(req.body));

  // 1. Authenticate using Authorization: Apikey <SEPAY_API_KEY>
  const authHeader = req.headers['authorization'];
  const expectedAuth = `Apikey ${SEPAY_API_KEY}`;
  
  if (!authHeader || authHeader !== expectedAuth) {
    console.error(`[Webhook] Xác thực thất bại. Header: "${authHeader}". Mong đợi: "${expectedAuth}"`);
    return res.status(401).json({ error: 'Unauthorized. Invalid API Key.' });
  }

  const { id, transferType, transferAmount, code, content } = req.body;

  // 2. Only process "in" transferType (money received)
  if (transferType !== 'in') {
    console.log(`[Webhook] Bỏ qua vì transferType là "${transferType}" (chỉ xử lý "in").`);
    return res.status(200).json({ success: true, message: 'Skipped non-inflow transaction.' });
  }

  // 3. Idempotency using transaction ID
  const txId = id ? id.toString() : null;
  if (!txId) {
    console.error('[Webhook] Giao dịch không có ID hợp lệ.');
    return res.status(400).json({ error: 'Transaction ID is required.' });
  }

  if (processedTransactions.has(txId)) {
    console.log(`[Webhook] Trùng giao dịch. ID "${txId}" đã được xử lý từ trước. Trả về thành công.`);
    return res.status(200).json({ success: true, message: 'Transaction already processed (Idempotent).' });
  }

  // 4. Find orderCode in code/content using regex: DH + 8 alphanumeric chars
  const regex = /DH[A-Z0-9]{8}/i;
  let match = null;

  if (code) match = code.match(regex);
  if (!match && content) match = content.match(regex);

  if (!match) {
    console.warn(`[Webhook] Không tìm thấy mã đơn hàng DH... trong code ("${code}") hoặc content ("${content}"). Ghi log và bỏ qua.`);
    return res.status(200).json({ success: true, message: 'Order code not found in transaction description.' });
  }

  const orderCode = match[0].toUpperCase();
  const order = orders.get(orderCode);

  if (!order) {
    console.warn(`[Webhook] Không tìm thấy đơn hàng khớp với mã đơn tìm được: "${orderCode}". Ghi log và bỏ qua.`);
    return res.status(200).json({ success: true, message: `Order ${orderCode} not found in database.` });
  }

  // Check and update expiration state dynamically to see if it was expired
  checkAndUpdateExpiration(order);

  // Mark transaction as processed
  processedTransactions.add(txId);

  // 5. Audit transferAmount against stored order.amount
  const expectedAmount = Number(order.amount);
  const actualAmount = Number(transferAmount);

  if (isNaN(actualAmount)) {
    console.error(`[Webhook] Số tiền chuyển khoản không hợp lệ: ${transferAmount}`);
    return res.status(400).json({ error: 'Invalid transferAmount.' });
  }

  order.actualPaidAmount = actualAmount;

  if (actualAmount < expectedAmount) {
    // Underpaid: keep pending, write warning notes
    order.notes = `Thiếu tiền: Khách chuyển ${actualAmount}đ, cần ${expectedAmount}đ (Thiếu ${expectedAmount - actualAmount}đ).`;
    console.warn(`[Webhook] Đơn hàng ${orderCode} thiếu tiền. Cần: ${expectedAmount}đ, Thực nhận: ${actualAmount}đ. Trạng thái giữ PENDING.`);
  } else if (actualAmount === expectedAmount) {
    // Paid in full
    order.status = 'paid';
    order.overpaid = false;
    order.notes = 'Thanh toán thành công (Đủ tiền)';
    console.log(`[Webhook] Đơn hàng ${orderCode} thanh toán THÀNH CÔNG (Đủ tiền: ${actualAmount}đ).`);
  } else {
    // Overpaid: status = paid, set overpaid = true, write notes
    order.status = 'paid';
    order.overpaid = true;
    order.notes = `Dư tiền: Khách chuyển ${actualAmount}đ, cần ${expectedAmount}đ (Dư ${actualAmount - expectedAmount}đ).`;
    console.log(`[Webhook] Đơn hàng ${orderCode} thanh toán THÀNH CÔNG (DƯ TIỀN - Cần: ${expectedAmount}đ, Thực nhận: ${actualAmount}đ).`);
  }

  return res.status(200).json({ success: true, orderCode, status: order.status, notes: order.notes });
});

// 4. GET /api/qr - Proxy to fetch QR from vietqr.app to avoid Flutter Web CORS issue
const https = require('https');
app.get('/api/qr', (req, res) => {
  const { acc, bank, amount, des, template } = req.query;
  const targetUrl = `https://vietqr.app/img?acc=${acc || ''}&bank=${bank || ''}&amount=${amount || ''}&des=${des || ''}&template=${template || ''}`;

  https.get(targetUrl, (targetRes) => {
    res.setHeader('Content-Type', targetRes.headers['content-type'] || 'image/png');
    targetRes.pipe(res);
  }).on('error', (err) => {
    console.error('[QR Proxy Error]', err);
    res.status(500).send('Error fetching QR image');
  });
});

// Start express server
app.listen(PORT, () => {
  console.log(`=======================================================`);
  console.log(`  SePay Webhook Server is running on port: ${PORT}`);
  console.log(`  Expected API Key: ${SEPAY_API_KEY}`);
  console.log(`  Bank Account: ${BANK_ACCOUNT} (${BANK_NAME})`);
  console.log(`  Order Expiration Limit: ${ORDER_EXPIRE_MINUTES} minutes`);
  console.log(`=======================================================`);
});
