import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getProducts from "@salesforce/apex/ProductCatalogueController.getProducts";
import setActiveStatus from "@salesforce/apex/ProductCatalogueController.setActiveStatus";
import getRecentPriceChanges from "@salesforce/apex/ProductCatalogueController.getRecentPriceChanges";

const CATEGORY_OPTIONS = [
  { label: "All Categories", value: "" },
  { label: "Hardware", value: "Hardware" },
  { label: "Software", value: "Software" },
  { label: "Service", value: "Service" }
];

const DEFAULT_SORT_FIELD = "Name";
const DEFAULT_SORT_DIRECTION = "ASC";
const PRICE_HISTORY_LIMIT = 5;

function toCurrencyNumber(value) {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const parsed = Number(value);
  return Number.isNaN(parsed) ? null : parsed;
}

export default class ProductCatalogue extends LightningElement {
  categoryFilter = "";
  sortField = DEFAULT_SORT_FIELD;
  sortDirection = DEFAULT_SORT_DIRECTION;

  products = [];
  errorMessage;
  isLoading = true;

  expandedProductIds = new Set();
  loadingHistoryProductIds = new Set();
  priceHistoryByProductId = {};
  historyErrorByProductId = {};

  categoryOptions = CATEGORY_OPTIONS;

  get isSortedByName() {
    return this.sortField === "Name";
  }

  get isSortedByPrice() {
    return this.sortField === "Unit_Price__c";
  }

  get nameColumnAriaSort() {
    return this.ariaSortFor(this.isSortedByName);
  }

  get priceColumnAriaSort() {
    return this.ariaSortFor(this.isSortedByPrice);
  }

  get sortIconName() {
    return this.sortDirection === "ASC"
      ? "utility:arrowup"
      : "utility:arrowdown";
  }

  get sortIconAlternativeText() {
    return this.sortDirection === "ASC"
      ? "Sorted ascending"
      : "Sorted descending";
  }

  ariaSortFor(isActiveColumn) {
    if (!isActiveColumn) {
      return "none";
    }
    return this.sortDirection === "ASC" ? "ascending" : "descending";
  }

  connectedCallback() {
    this.isLoading = true;
    this.loadProducts();
  }

  async loadProducts() {
    try {
      const data = await getProducts({
        categoryFilter: this.categoryFilter,
        sortField: this.sortField,
        sortDirection: this.sortDirection
      });
      this.errorMessage = undefined;
      this.products = data.map((product) => this.toRow(product));
    } catch (error) {
      this.products = [];
      this.errorMessage = this.extractErrorMessage(
        error,
        "We couldn’t load the product catalogue."
      );
    } finally {
      this.isLoading = false;
    }
  }

  toRow(product) {
    return {
      id: product.Id,
      name: product.Name,
      category: product.Category__c,
      unitPrice: product.Unit_Price__c,
      isActive: product.Active__c,
      toggleLabel: product.Active__c ? "Active" : "Inactive"
    };
  }

  get hasProducts() {
    return this.products.length > 0;
  }

  get showEmptyState() {
    return !this.isLoading && !this.errorMessage && !this.hasProducts;
  }

  handleCategoryChange(event) {
    this.categoryFilter = event.detail.value;
    this.loadProducts();
  }

  handleSortByColumn(event) {
    const field = event.currentTarget.dataset.field;
    if (this.sortField === field) {
      this.sortDirection = this.sortDirection === "ASC" ? "DESC" : "ASC";
    } else {
      this.sortField = field;
      this.sortDirection = DEFAULT_SORT_DIRECTION;
    }
    this.expandedProductIds = new Set();
    this.loadProducts();
  }

  async handleToggleActive(event) {
    const productId = event.target.dataset.id;
    const newValue = event.detail.checked;
    const row = this.products.find((product) => product.id === productId);
    if (!row) {
      return;
    }

    const previousValue = row.isActive;
    this.updateRow(productId, {
      isActive: newValue,
      toggleLabel: newValue ? "Active" : "Inactive"
    });

    try {
      await setActiveStatus({ productId, isActive: newValue });
      this.showToast("Success", "Product status updated.", "success");
      await this.loadProducts();
    } catch (error) {
      this.updateRow(productId, {
        isActive: previousValue,
        toggleLabel: previousValue ? "Active" : "Inactive"
      });
      this.showToast(
        "Error updating status",
        this.extractErrorMessage(error, "We couldn’t update this product."),
        "error"
      );
    }
  }

  updateRow(productId, changes) {
    this.products = this.products.map((product) => {
      if (product.id !== productId) {
        return product;
      }
      return { ...product, ...changes };
    });
  }

  isRowExpanded(productId) {
    return this.expandedProductIds.has(productId);
  }

  isHistoryLoading(productId) {
    return this.loadingHistoryProductIds.has(productId);
  }

  get rows() {
    return this.products.map((product) => {
      const isExpanded = this.isRowExpanded(product.id);
      const isLoadingHistory = this.isHistoryLoading(product.id);
      const historyError = this.historyErrorByProductId[product.id];
      const history = this.priceHistoryByProductId[product.id] || [];

      return {
        ...product,
        isExpanded,
        isLoadingHistory,
        historyError,
        history,
        hasHistory: history.length > 0,
        showHistoryEmptyState:
          !isLoadingHistory && !historyError && history.length === 0,
        historyButtonLabel: isExpanded
          ? "Hide Price History"
          : "View Price History",
        historyRowKey: `${product.id}-history`
      };
    });
  }

  async handleToggleHistory(event) {
    const productId = event.target.dataset.id;

    const expandedProductIds = new Set(this.expandedProductIds);
    if (expandedProductIds.has(productId)) {
      expandedProductIds.delete(productId);
      this.expandedProductIds = expandedProductIds;
      return;
    }
    expandedProductIds.add(productId);
    this.expandedProductIds = expandedProductIds;

    if (this.priceHistoryByProductId[productId]) {
      return;
    }

    this.loadingHistoryProductIds = new Set(this.loadingHistoryProductIds).add(
      productId
    );
    try {
      const history = await getRecentPriceChanges({
        productId,
        maxRecords: PRICE_HISTORY_LIMIT
      });
      this.priceHistoryByProductId = {
        ...this.priceHistoryByProductId,
        [productId]: history.map((change) => ({
          changedDate: change.changedDate,
          oldValue: toCurrencyNumber(change.oldValue),
          newValue: toCurrencyNumber(change.newValue)
        }))
      };
      this.historyErrorByProductId = {
        ...this.historyErrorByProductId,
        [productId]: undefined
      };
    } catch (error) {
      this.historyErrorByProductId = {
        ...this.historyErrorByProductId,
        [productId]: this.extractErrorMessage(
          error,
          "We couldn’t load the price history for this product."
        )
      };
    } finally {
      const loadingHistoryProductIds = new Set(this.loadingHistoryProductIds);
      loadingHistoryProductIds.delete(productId);
      this.loadingHistoryProductIds = loadingHistoryProductIds;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  extractErrorMessage(error, fallbackMessage) {
    if (
      error &&
      error.body &&
      typeof error.body.message === "string" &&
      error.body.message
    ) {
      return error.body.message;
    }
    if (error && typeof error.message === "string" && error.message) {
      return error.message;
    }
    return fallbackMessage;
  }
}
