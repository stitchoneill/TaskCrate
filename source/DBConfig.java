package source;

import java.io.InputStream;
import java.util.Properties;
import javax.servlet.ServletContext;

public class DBConfig {

    // reads the database path from /WEB-INF/config.properties
    public static String getDbPath(ServletContext context) {
        try (InputStream input = context.getResourceAsStream("/WEB-INF/config.properties")) {
            Properties prop = new Properties();
            prop.load(input);

            // return the value set under "db.path"
            return prop.getProperty("db.path");

        } catch (Exception e) {
            // if anything goes wrong, stop everything with a clear error
            throw new RuntimeException("Could not load DB path from config!", e);
        }
    }
}
