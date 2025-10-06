package source;

// links a job to an inventory item and how many were used
public class JobItem {
    private int jobItemId;   // row id for this link (if you need it)
    private int jobId;       // which job this belongs to
    private int itemId;      // which inventory item was used
    private int quantityUsed;// how many of that item the job used

    public JobItem() {
        // empty on purpose
    }

    // handy when creating a link quickly (no jobItemId yet)
    public JobItem(int jobId, int itemId, int quantityUsed) {
        this.jobId = jobId;
        this.itemId = itemId;
        this.quantityUsed = quantityUsed;
    }

    // getters/setters below are straightforward

    public int getJobItemId() {
        return jobItemId;
    }

    public void setJobItemId(int jobItemId) {
        this.jobItemId = jobItemId;
    }

    public int getJobId() {
        return jobId;
    }

    public void setJobId(int jobId) {
        this.jobId = jobId;
    }

    public int getItemId() {
        return itemId;
    }

    public void setItemId(int itemId) {
        this.itemId = itemId;
    }

    public int getQuantityUsed() {
        return quantityUsed;
    }

    public void setQuantityUsed(int quantityUsed) {
        this.quantityUsed = quantityUsed;
    }
}
