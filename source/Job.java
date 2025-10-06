package source;

// simple data holder for a job (id, name, description, date, status)
public class Job {
    private int jobId;
    private String name;
    private String description;
    private String scheduledDate; // when the job is planned for
    private String status;        // e.g. Planned, Completed, Deleted, etc.

    // job id getter/setter
    public int getJobId() {
        return jobId;
    }
    public void setJobId(int jobId) {
        this.jobId = jobId;
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

    // scheduled date getter/setter
    public String getScheduledDate() {
        return scheduledDate;
    }
    public void setScheduledDate(String scheduledDate) {
        this.scheduledDate = scheduledDate;
    }

    // status getter/setter
    public String getStatus() {
        return status;
    }
    public void setStatus(String status) {
        this.status = status;
    }
}
