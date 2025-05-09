import com.atlassian.bamboo.specs.api.BambooSpec;
import com.atlassian.bamboo.specs.api.builders.AtlassianModule;
import com.atlassian.bamboo.specs.api.builders.BambooKey;
import com.atlassian.bamboo.specs.api.builders.BambooOid;
import com.atlassian.bamboo.specs.api.builders.docker.DockerConfiguration;
import com.atlassian.bamboo.specs.api.builders.permission.PermissionType;
import com.atlassian.bamboo.specs.api.builders.permission.Permissions;
import com.atlassian.bamboo.specs.api.builders.permission.PlanPermissions;
import com.atlassian.bamboo.specs.api.builders.plan.Job;
import com.atlassian.bamboo.specs.api.builders.plan.Plan;
import com.atlassian.bamboo.specs.api.builders.plan.PlanIdentifier;
import com.atlassian.bamboo.specs.api.builders.plan.Stage;
import com.atlassian.bamboo.specs.api.builders.plan.branches.BranchCleanup;
import com.atlassian.bamboo.specs.api.builders.plan.branches.PlanBranchManagement;
import com.atlassian.bamboo.specs.api.builders.plan.configuration.ConcurrentBuilds;
import com.atlassian.bamboo.specs.api.builders.plan.configuration.ForceStopBuild;
import com.atlassian.bamboo.specs.api.builders.project.Project;
import com.atlassian.bamboo.specs.api.builders.task.AnyTask;
import com.atlassian.bamboo.specs.builders.task.CheckoutItem;
import com.atlassian.bamboo.specs.builders.task.VcsCheckoutTask;
import com.atlassian.bamboo.specs.builders.trigger.RepositoryPollingTrigger;
import com.atlassian.bamboo.specs.util.BambooServer;
import com.atlassian.bamboo.specs.util.MapBuilder;

@BambooSpec
public class PlanSpec {
    
    public Plan plan() {
        final Plan plan = new Plan(new Project()
                .oid(new BambooOid("rnl8i5pnngu9"))
                .key(new BambooKey("MYF"))
                .name("MyFirstProject"),
            "MyFirstTaskPlan",
            new BambooKey("MYFT"))
            .oid(new BambooOid("rnbjakcftog1"))
            .pluginConfigurations(new ConcurrentBuilds(),
                new ForceStopBuild()
                    .enabled(true))
            .stages(new Stage("Default Stage")
                    .jobs(new Job("Default Job",
                            new BambooKey("JOB1"))
                            .tasks(new VcsCheckoutTask()
                                    .description("Checkout Default Repository")
                                    .checkoutItems(new CheckoutItem().defaultRepository()),
                                new AnyTask(new AtlassianModule("org.jfrog.bamboo.bamboo-jfrog-plugin:JfTask"))
                                    .description("Demo task description")
                                    .configuration(new MapBuilder()
                                            .put("jf.task.server.id", "YT")
                                            .put("jf.task.command", "jf except in java")
                                            .put("jf.task.working.directory", "/tmp/nodirectory")
                                            .build()))
                            .dockerConfiguration(new DockerConfiguration()
                                    .enabled(false))))
            .linkedRepositories("Bamboo-helloJava")
            
            .triggers(new RepositoryPollingTrigger())
            .planBranchManagement(new PlanBranchManagement()
                    .delete(new BranchCleanup())
                    .notificationLikeParentPlan());
        return plan;
    }
    
    public PlanPermissions planPermission() {
        final PlanPermissions planPermission = new PlanPermissions(new PlanIdentifier("MYF", "MYFT"))
            .permissions(new Permissions()
                    .userPermissions("admin", PermissionType.ADMIN, PermissionType.CREATE_PLAN_BRANCH, PermissionType.CLONE, PermissionType.BUILD, PermissionType.VIEW_CONFIGURATION, PermissionType.VIEW, PermissionType.EDIT)
                    .loggedInUserPermissions(PermissionType.VIEW)
                    .anonymousUserPermissionView());
        return planPermission;
    }
    
    public static void main(String... argv) {
        //By default credentials are read from the '.credentials' file.
        BambooServer bambooServer = new BambooServer("http://localhost:6990/bamboo");
        final PlanSpec planSpec = new PlanSpec();
        
        final Plan plan = planSpec.plan();
        bambooServer.publish(plan);
        
        final PlanPermissions planPermission = planSpec.planPermission();
        bambooServer.publish(planPermission);
    }
}