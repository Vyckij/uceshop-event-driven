/* =====================================================================
 * UCEShop Dashboard · lógica de la aplicación (JavaScript puro)
 *
 * Todas las URLs salen de CONFIG (js/config.js).
 * Secciones:
 *   1) Crear pedido          → POST  {PRODUCER_URL}/orders
 *   2) Pedidos procesados    → GET   {CONSUMER_URL}/processed-orders
 *   3) Estado de servicios   → GET   {PRODUCER_URL|CONSUMER_URL}/actuator/health
 *   4) Métricas              → GET   {PROMETHEUS_API_URL}/api/v1/query
 *   5) Monitoreo             → enlaces a RabbitMQ, Prometheus y Grafana
 * ===================================================================== */
"use strict";

(function () {

  // -------------------------------------------------------------------
  // 0. Comprobaciones iniciales
  // -------------------------------------------------------------------
  if (typeof CONFIG === "undefined") {
    document.getElementById("configWarning").classList.remove("d-none");
    return;
  }

  if (window.location.protocol === "file:") {
    document.getElementById("protocolWarning").classList.remove("d-none");
  }

  // -------------------------------------------------------------------
  // Utilidades
  // -------------------------------------------------------------------
  const byId = (id) => document.getElementById(id);

  const moneyFormat = new Intl.NumberFormat("es-EC", { style: "currency", currency: "USD" });
  const numberFormat = new Intl.NumberFormat("es-EC", { maximumFractionDigits: 0 });

  const formatDate = (iso) => (iso ? new Date(iso).toLocaleString("es-EC") : "—");
  const formatTime = (date) => date.toLocaleTimeString("es-EC");

  /** Une la URL base de config.js con una ruta, evitando dobles "/". */
  const buildUrl = (base, path) => base.replace(/\/+$/, "") + path;

  /**
   * Crea un elemento HTML de forma SEGURA.
   * Usa textContent (no innerHTML), así un texto como "<script>" escrito
   * en el formulario nunca se ejecuta (protección contra XSS).
   */
  function el(tag, options = {}, children = []) {
    const element = document.createElement(tag);
    if (options.className) element.className = options.className;
    if (options.text !== undefined) element.textContent = options.text;
    if (options.title) element.title = options.title;
    if (options.attrs) {
      Object.entries(options.attrs).forEach(([name, value]) => element.setAttribute(name, value));
    }
    children.forEach((child) => element.appendChild(child));
    return element;
  }

  /**
   * fetch con tiempo máximo y medición del tiempo de respuesta.
   * Nunca lanza excepción: siempre devuelve { ok, status, data, elapsedMs, networkError }.
   */
  async function fetchJson(url, options = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), CONFIG.REQUEST_TIMEOUT_MS);
    const start = performance.now();

    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal,
        headers: { Accept: "application/json", ...(options.headers || {}) }
      });
      const elapsedMs = Math.round(performance.now() - start);
      const text = await response.text();
      let data = null;
      try {
        data = text ? JSON.parse(text) : null;
      } catch (parseError) {
        data = null;   // la respuesta no era JSON (por ejemplo, una página de error 502)
      }
      return { ok: response.ok, status: response.status, data, elapsedMs };
    } catch (error) {
      const elapsedMs = Math.round(performance.now() - start);
      const networkError = error.name === "AbortError"
        ? `Tiempo de espera agotado (${CONFIG.REQUEST_TIMEOUT_MS / 1000} s)`
        : "No se pudo conectar con el servicio";
      return { ok: false, status: 0, data: null, elapsedMs, networkError };
    } finally {
      clearTimeout(timer);
    }
  }

  // -------------------------------------------------------------------
  // Configuración visible: entorno y enlaces de monitoreo (SECCIÓN 5)
  // -------------------------------------------------------------------
  function applyConfig() {
    byId("envText").textContent = CONFIG.ENVIRONMENT;

    document.querySelectorAll("[data-config-link]").forEach((link) => {
      link.href = CONFIG[link.dataset.configLink];
    });
    document.querySelectorAll("[data-config-text]").forEach((node) => {
      node.textContent = CONFIG[node.dataset.configText];
    });
  }

  // -------------------------------------------------------------------
  // SECCIÓN 1 · Crear pedido
  // -------------------------------------------------------------------
  const orderForm = byId("orderForm");
  const orderResult = byId("orderResult");
  const orderHistory = byId("orderHistory");
  const submitButton = byId("submitButton");
  const history = [];

  function readNumber(id, parser) {
    const raw = byId(id).value.trim();
    if (raw === "") return null;
    const value = parser(raw);
    return Number.isNaN(value) ? null : value;
  }

  function setSubmitting(isSubmitting) {
    submitButton.disabled = isSubmitting;
    byId("submitSpinner").classList.toggle("d-none", !isSubmitting);
    byId("submitIcon").classList.toggle("d-none", isSubmitting);
  }

  // Catálogo: "name" es el texto que se envía como "product" a POST /orders
  const PRODUCT_CATALOG = [
    { name: "Laptop Lenovo",    price: 750 },
    { name: "Monitor Dell 27",  price: 300 },
    { name: "Mouse Logitech",   price: 25 },
    { name: "Teclado Mecánico", price: 80 },
    { name: "Audífonos Sony",   price: 120 }
  ];

  const productSelect = byId("product");
  const quantityInput = byId("quantity");
  const unitPriceInput = byId("unitPrice");
  const totalInput = byId("orderTotal");

  /** Crea las opciones del desplegable a partir del catálogo. */
  function loadProductOptions() {
    PRODUCT_CATALOG.forEach((item) => {
      productSelect.appendChild(el("option", {
        text: `${item.name} — ${moneyFormat.format(item.price)}`,
        attrs: { value: item.name }
      }));
    });
  }

  /** Al elegir un producto se completa su precio (el usuario puede cambiarlo después). */
  function applyCatalogPrice() {
    const item = PRODUCT_CATALOG.find((product) => product.name === productSelect.value);
    unitPriceInput.value = item ? item.price.toFixed(2) : "";
    updateTotal();
  }

  /** Total = cantidad × precio unitario. Solo se muestra: el producer calcula el suyo. */
  function updateTotal() {
    const quantity = readNumber("quantity", (v) => parseInt(v, 10));
    const unitPrice = readNumber("unitPrice", parseFloat);
    const valid = quantity !== null && unitPrice !== null && quantity > 0 && unitPrice > 0;
    const total = valid ? Math.round(quantity * unitPrice * 100) / 100 : 0;
    totalInput.value = moneyFormat.format(total);
  }

  function fillExample(quantity) {
    const item = PRODUCT_CATALOG[Math.floor(Math.random() * PRODUCT_CATALOG.length)];
    byId("customerId").value = `C-${Math.floor(Math.random() * 900) + 100}`;
    productSelect.value = item.name;
    quantityInput.value = quantity;
    applyCatalogPrice();
  }

  function renderOrderResult(result) {
    orderResult.replaceChildren();

    const timeBadge = el("span", {
      className: `badge ms-2 ${result.elapsedMs < 500 ? "text-bg-success" : "text-bg-warning"}`,
      text: `${result.elapsedMs} ms`
    });

    let alertClass;
    let title;
    const details = [];

    if (result.status === 202 && result.data) {
      alertClass = "alert-success";
      title = "Pedido aceptado (HTTP 202)";
      details.push(`Order ID: ${result.data.orderId}`);
      details.push(`Total: ${moneyFormat.format(result.data.total)} · Estado: ${result.data.status}`);
      details.push("Kafka lo entregará al consumer en segundos.");
    } else if (result.status === 400) {
      alertClass = "alert-warning";
      title = "Datos inválidos (HTTP 400)";
      const errors = (result.data && result.data.errors) || {};
      const messages = Object.values(errors);
      if (messages.length === 0) messages.push("Revisa los datos del formulario.");
      details.push(...messages);
    } else if (result.status === 503) {
      alertClass = "alert-danger";
      title = "Kafka no disponible (HTTP 503)";
      details.push((result.data && result.data.detail) || "El pedido no fue registrado. Intenta nuevamente.");
    } else if (result.status === 0) {
      alertClass = "alert-danger";
      title = "Sin conexión con el producer";
      details.push(result.networkError);
    } else {
      alertClass = "alert-danger";
      title = `Error inesperado (HTTP ${result.status})`;
      details.push((result.data && (result.data.detail || result.data.error)) || "Revisa los logs del producer-service.");
    }

    const heading = el("div", { className: "fw-semibold d-flex align-items-center flex-wrap" }, [
      el("span", { text: title }), timeBadge
    ]);
    const list = el("ul", { className: "mb-0 mt-2 small ps-3" },
      details.map((line) => el("li", { text: line })));

    orderResult.appendChild(el("div", { className: `alert ${alertClass} mb-0`, attrs: { role: "alert" } },
      [heading, list]));
  }

  function renderHistory() {
    orderHistory.replaceChildren();
    history.forEach((item) => {
      const badgeClass = item.status === 202 ? "text-bg-success"
        : item.status === 400 ? "text-bg-warning" : "text-bg-danger";
      const statusText = item.status === 0 ? "sin conexión" : `HTTP ${item.status}`;
      orderHistory.appendChild(el("li", { className: "list-group-item px-0 d-flex justify-content-between gap-2" }, [
        el("span", { className: "text-truncate", text: `${item.time} · ${item.product || "(sin producto)"} × ${item.quantity ?? "?"}` }),
        el("span", { className: "text-nowrap" }, [
          el("span", { className: `badge ${badgeClass} me-1`, text: statusText }),
          el("span", { className: "text-secondary", text: `${item.elapsedMs} ms` })
        ])
      ]));
    });
  }

  async function submitOrder(event) {
    event.preventDefault();

    const order = {
      customerId: byId("customerId").value.trim(),
      product: byId("product").value.trim(),
      quantity: readNumber("quantity", (v) => parseInt(v, 10)),
      unitPrice: readNumber("unitPrice", parseFloat)
    };

    setSubmitting(true);
    const result = await fetchJson(buildUrl(CONFIG.PRODUCER_URL, "/orders"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(order)
    });
    setSubmitting(false);

    renderOrderResult(result);

    history.unshift({
      time: formatTime(new Date()),
      product: order.product,
      quantity: order.quantity,
      status: result.status,
      elapsedMs: result.elapsedMs
    });
    history.splice(5);
    renderHistory();

    // Si se aceptó, refresca la tabla en 2 s para verlo llegar desde Kafka
    if (result.status === 202) {
      setTimeout(loadProcessedOrders, 2000);
    }
  }

  orderForm.addEventListener("submit", submitOrder);
  productSelect.addEventListener("change", applyCatalogPrice);
  quantityInput.addEventListener("input", updateTotal);
  unitPriceInput.addEventListener("input", updateTotal);
  byId("fillValidButton").addEventListener("click", () => fillExample(Math.floor(Math.random() * 5) + 1));
  byId("fillDlqButton").addEventListener("click", () => fillExample(150));

  loadProductOptions();
  updateTotal();
  // -------------------------------------------------------------------
  // SECCIÓN 2 · Pedidos procesados
  // -------------------------------------------------------------------
  const ordersTableBody = byId("ordersTableBody");
  const productFilter = byId("productFilter");
  const autoRefreshSwitch = byId("autoRefreshSwitch");
  let processedOrders = [];
  let ordersError = null;
  const knownOrderIds = new Set();
  let firstOrdersLoad = true;

  function messageRow(text, className = "text-secondary") {
    return el("tr", {}, [el("td", { className: `text-center py-4 ${className}`, text, attrs: { colspan: "7" } })]);
  }

  function renderOrders() {
    ordersTableBody.replaceChildren();

    if (ordersError) {
      ordersTableBody.appendChild(messageRow(ordersError, "text-danger"));
      byId("ordersCount").textContent = "0";
      return;
    }

    const filter = productFilter.value.trim().toLowerCase();
    const visible = processedOrders.filter((order) =>
      (order.product || "").toLowerCase().includes(filter));

    byId("ordersCount").textContent = filter
      ? `${visible.length} de ${processedOrders.length}`
      : String(processedOrders.length);

    if (visible.length === 0) {
      ordersTableBody.appendChild(messageRow(filter
        ? "Ningún pedido coincide con el filtro."
        : "Todavía no hay pedidos procesados. Envía uno desde el formulario."));
      return;
    }

    visible.forEach((order) => {
      const isNew = !firstOrdersLoad && !knownOrderIds.has(order.orderId);
      const shortId = String(order.orderId).slice(0, 8) + "…";

      ordersTableBody.appendChild(el("tr", { className: isNew ? "row-new" : "" }, [
        el("td", {}, [el("span", { className: "order-id", text: shortId, title: order.orderId })]),
        el("td", { text: order.customerId }),
        el("td", { text: order.product }),
        el("td", { className: "text-end", text: numberFormat.format(order.quantity) }),
        el("td", { className: "text-end fw-semibold", text: moneyFormat.format(order.total) }),
        el("td", { className: "text-center" }, [
          el("span", { className: "badge text-bg-dark", text: `P${order.kafkaPartition}`, title: `offset ${order.kafkaOffset}` })
        ]),
        el("td", { className: "text-nowrap small", text: formatDate(order.processedAt) })
      ]));
    });
  }
  async function loadProcessedOrders() {
    const result = await fetchJson(buildUrl(CONFIG.CONSUMER_URL, "/processed-orders"));

    if (result.ok && Array.isArray(result.data)) {
      ordersError = null;
      processedOrders = result.data;
      renderOrders();
      processedOrders.forEach((order) => knownOrderIds.add(order.orderId));
      firstOrdersLoad = false;
      byId("ordersUpdated").textContent = `Actualizado ${formatTime(new Date())}`;
    } else {
      ordersError = result.status === 0
        ? `No se pudo consultar el consumer-service: ${result.networkError}.`
        : `El consumer-service respondió HTTP ${result.status}.`;
      renderOrders();
    }
  }
  productFilter.addEventListener("input", renderOrders);

  // -------------------------------------------------------------------
  // SECCIÓN 3 · Estado de servicios
  // -------------------------------------------------------------------
  async function checkHealth(serviceKey, baseUrl) {
    const result = await fetchJson(buildUrl(baseUrl, "/actuator/health"));
    const status = (result.data && result.data.status) || (result.ok ? "UP" : "DOWN");
    const isUp = status === "UP";

    const card = byId(`${serviceKey}Card`);
    const pill = byId(`${serviceKey}Status`);
    card.classList.toggle("is-up", isUp);
    card.classList.toggle("is-down", !isUp);
    pill.className = `status-pill ${isUp ? "status-up" : "status-down"}`;
    pill.textContent = isUp ? "🟢 UP" : "🔴 DOWN";

    // Componentes internos: db, rabbit, diskSpace, livenessState...
    const componentsBox = byId(`${serviceKey}Components`);
    componentsBox.replaceChildren();
    const components = (result.data && result.data.components) || {};
    Object.entries(components).forEach(([name, info]) => {
      const componentUp = info && info.status === "UP";
      componentsBox.appendChild(el("span", {
        className: `component-badge ${componentUp ? "up" : "down"}`,
        text: `${name}: ${info ? info.status : "?"}`
      }));
    });

    const reason = result.status === 0 ? ` · ${result.networkError}` : "";
    byId(`${serviceKey}Meta`).textContent =
      `Respuesta en ${result.elapsedMs} ms · HTTP ${result.status || "—"}${reason} · ${formatTime(new Date())}`;

    // Puntos de estado en el diagrama de arquitectura
    document.querySelectorAll(`[data-health-dot="${serviceKey}"]`).forEach((dot) => {
      dot.classList.toggle("up", isUp);
      dot.classList.toggle("down", !isUp);
    });
  }

  // -------------------------------------------------------------------
  // SECCIÓN 4 · Métricas (Prometheus)
  // -------------------------------------------------------------------
  const METRICS = [
    { elementId: "metricPublished",     query: "sum(uceshop_orders_events_published_total)" },
    { elementId: "metricProcessed",     query: "sum(uceshop_orders_events_processed_total)" },
    { elementId: "metricFailed",        query: "sum(uceshop_orders_events_failed_total)" },
    { elementId: "metricNotifications", query: "sum(uceshop_orders_notifications_published_total)" }
  ];

  /** Ejecuta una consulta PromQL y devuelve un número (o null si falla). */
  async function queryPrometheus(promql) {
    const url = buildUrl(CONFIG.PROMETHEUS_API_URL, "/api/v1/query?query=" + encodeURIComponent(promql));
    const result = await fetchJson(url);
    if (!result.ok || !result.data || result.data.status !== "success") return null;
    const series = result.data.data.result;
    if (!series || series.length === 0) return 0;   // la métrica aún no existe → 0
    const value = Number(series[0].value[1]);
    return Number.isFinite(value) ? value : 0;
  }

  async function loadMetrics() {
    const values = await Promise.all(METRICS.map((metric) => queryPrometheus(metric.query)));
    let available = 0;

    values.forEach((value, index) => {
      const node = byId(METRICS[index].elementId);
      if (value === null) {
        node.textContent = "—";
      } else {
        node.textContent = numberFormat.format(Math.round(value));
        available++;
      }
    });

    const source = byId("metricsSource");
    source.textContent = available > 0 ? "conectado" : "sin conexión";
    source.className = `fw-semibold ${available > 0 ? "text-success" : "text-danger"}`;
  }

  // -------------------------------------------------------------------
  // Ciclo de actualización automática
  // -------------------------------------------------------------------
  let refreshing = false;

  async function refreshAll() {
    if (refreshing || document.hidden) return;   // no se acumulan peticiones
    refreshing = true;
    try {
      const tasks = [
        checkHealth("producer", CONFIG.PRODUCER_URL),
        checkHealth("consumer", CONFIG.CONSUMER_URL),
        loadMetrics()
      ];
      if (autoRefreshSwitch.checked) tasks.push(loadProcessedOrders());
      await Promise.allSettled(tasks);
      byId("lastRefresh").textContent = formatTime(new Date());
    } finally {
      refreshing = false;
    }
  }

  autoRefreshSwitch.addEventListener("change", () => {
    if (autoRefreshSwitch.checked) loadProcessedOrders();
  });

  // -------------------------------------------------------------------
  // Inicio
  // -------------------------------------------------------------------
  applyConfig();
  refreshAll();                                          // primera carga inmediata
  setInterval(refreshAll, CONFIG.REFRESH_INTERVAL_MS);   // y luego cada 5 s
})();
