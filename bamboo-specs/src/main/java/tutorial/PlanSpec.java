package tutorial;

import com.atlassian.bamboo.specs.api.BambooSpec;
import com.atlassian.bamboo.specs.api.builders.AtlassianModule;
import com.atlassian.bamboo.specs.api.builders.BambooKey;
import com.atlassian.bamboo.specs.api.builders.BambooOid;
import com.atlassian.bamboo.specs.api.builders.plan.Job;
import com.atlassian.bamboo.specs.api.builders.plan.Plan;
import com.atlassian.bamboo.specs.api.builders.plan.PlanIdentifier;
import com.atlassian.bamboo.specs.api.builders.plan.Stage;
import com.atlassian.bamboo.specs.api.builders.plan.branches.BranchCleanup;
import com.atlassian.bamboo.specs.api.builders.plan.branches.PlanBranchManagement;
import com.atlassian.bamboo.specs.api.builders.project.Project;
import com.atlassian.bamboo.specs.api.builders.task.AnyTask;
import com.atlassian.bamboo.specs.builders.task.CheckoutItem;
import com.atlassian.bamboo.specs.builders.task.VcsCheckoutTask;
import com.atlassian.bamboo.specs.builders.trigger.RepositoryPollingTrigger;
import com.atlassian.bamboo.specs.util.BambooServer;
import com.atlassian.bamboo.specs.api.builders.permission.Permissions;
import com.atlassian.bamboo.specs.api.builders.permission.PermissionType;
import com.atlassian.bamboo.specs.api.builders.permission.PlanPermissions;
import com.atlassian.bamboo.specs.util.MapBuilder;

/**
 * Plan configuration for Bamboo.
 * Learn more on: <a href="https://confluence.atlassian.com/display/BAMBOO/Bamboo+Specs">https://confluence.atlassian.com/display/BAMBOO/Bamboo+Specs</a>
 */
@BambooSpec
public class PlanSpec {

    /**
     * Run main to publish plan on Bamboo
     */
    public static void main(final String[] args) throws Exception {
        //By default credentials are read from the '.credentials' file.
        BambooServer bambooServer = new BambooServer("http://localhost:6990/bamboo");

        Plan plan = new PlanSpec().createPlan();

        bambooServer.publish(plan);

        PlanPermissions planPermission = new PlanSpec().createPlanPermission(plan.getIdentifier());

        bambooServer.publish(planPermission);
    }

    PlanPermissions createPlanPermission(PlanIdentifier planIdentifier) {
        Permissions permission = new Permissions()
                .userPermissions("admin", PermissionType.ADMIN, PermissionType.CLONE, PermissionType.EDIT)
                .groupPermissions("bamboo-admin", PermissionType.ADMIN)
                .loggedInUserPermissions(PermissionType.VIEW)
                .anonymousUserPermissionView();
        return new PlanPermissions(planIdentifier.getProjectKey(), planIdentifier.getPlanKey()).permissions(permission);
    }

    Plan createPlan() {
        return new Plan(new Project()
                .oid(new BambooOid("rnl8i5pnngu9"))
                .key(new BambooKey("MYF"))
                .name("MyFirstProject"),
                "MyFirstTaskPlan",
                new BambooKey("MYFT"))
                .oid(new BambooOid("rnbjakcftog1"))
//                .pluginConfigurations(new ConcurrentBuilds(),
//                        new ForceStopBuild()
//                                .enabled(true))
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
                                                        .build()))))
                .linkedRepositories("Bamboo-helloJava")

                .triggers(new RepositoryPollingTrigger())
                .planBranchManagement(new PlanBranchManagement()
                        .delete(new BranchCleanup())
                        .notificationLikeParentPlan());
    }

}
