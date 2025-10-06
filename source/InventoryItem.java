package source;

public class InventoryItem {
    private int itemId;
    private String name;
    private String description;
    private int quantity;
    private String status;

    // how low we allow stock before we call it "low" (default 2, same as DB)
    private int lowStockThreshold = 2;  // default to 2 just like DB

    public InventoryItem() {}

    // quick constructor when we don’t have an id yet
    public InventoryItem(String name, String description, int quantity, String status, int lowStockThreshold) {
        this.name = name;
        this.description = description;
        this.quantity = quantity;
        this.status = status;
        this.lowStockThreshold = lowStockThreshold;
    }

    // full constructor including id
    public InventoryItem(int itemId, String name, String description, int quantity, String status, int lowStockThreshold) {
        this.itemId = itemId;
        this.name = name;
        this.description = description;
        this.quantity = quantity;
        this.status = status;
        this.lowStockThreshold = lowStockThreshold;
    }
    
    // threshold getter/setter
    public int getLowStockThreshold() {
        return lowStockThreshold;
    }
    public void setLowStockThreshold(int lowStockThreshold) {
        this.lowStockThreshold = lowStockThreshold;
    }

    // id getter/setter
    public int getItemId() {
        return itemId;
    }
    public void setItemId(int itemId) {
        this.itemId = itemId;
    }

    // name getter/setter
    public String getName() {
        return name;
    }
    public void setName(String name) {
        this.name = name;
    }

    // description getter/setter
    public String getDescription() {
        return description;
    }
    public void setDescription(String description) {
        this.description = description;
    }

    // quantity getter/setter
    public int getQuantity() {
        return quantity;
    }
    public void setQuantity(int quantity) {
        this.quantity = quantity;
    }

    // status getter/setter (in_stock / low_stock / out_of_stock)
    public String getStatus() {
        return status;
    }
    public void setStatus(String status) {
        this.status = status;
    }

    // handy for logging/debugging
    @Override
    public String toString() {
        return itemId + ": " + name + " (" + quantity + " - " + status + ")";
    }
}
